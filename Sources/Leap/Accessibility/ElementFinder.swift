import AppKit
import ApplicationServices
import LeapCore

/// Collects click and scroll targets from the accessibility tree. This file has the tree
/// walk the others share; each kind of target has its own file:
/// `ElementFinder+ClickTargets` (apps and Leap's own window), `+MenuBar` (status items),
/// `+MissionControl` and `+ScrollAreas`.
@MainActor
enum ElementFinder {
    private static let nodeAttributes = [
        kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute,
        kAXEnabledAttribute, kAXChildrenAttribute,
    ]
    private static let maxNodes = 6000

    /// The first targets get the shortest labels; reading order puts them on the top-left
    /// controls rather than wherever the app's tree happens to start.
    static func inReadingOrder(_ targets: [Target]) -> [Target] {
        LabelLayout.readingOrder(targets.map(\.frame)).map { targets[$0] }
    }

    /// `transform` applied to every item at once, on several threads, in the items' order.
    /// Accessibility requests mostly wait for the other app, so asking many at once is faster.
    nonisolated static func concurrentMap<Item: Sendable, Result>(
        _ items: [Item], _ transform: @Sendable (Item) -> Result
    ) -> [Result] {
        // Each thread writes only its own slot. The results hold accessibility elements, which
        // Apple documents as safe to use from any thread but does not mark `Sendable`.
        let count = items.count
        nonisolated(unsafe) let slots = UnsafeMutableBufferPointer<Result?>.allocate(
            capacity: count)
        slots.initialize(repeating: nil)
        defer {
            slots.deinitialize()
            slots.deallocate()
        }
        DispatchQueue.concurrentPerform(iterations: items.count) { index in
            slots[index] = transform(items[index])
        }
        return slots.map { $0! }
    }

    // MARK: Tree walking

    struct Node {
        let element: AXUIElement
        let role: String?
        let subrole: String?
        let frame: CGRect?
        let enabled: Bool?
        let hasChildren: Bool
    }

    /// Depth-first walk where `visit` returns false to skip the node's children.
    static func walk(_ root: AXUIElement, visit: (Node, CGRect) -> Bool) {
        walk(root, context: ()) { node, clip, _ in visit(node, clip) ? () : nil }
    }

    /// Depth-first walk with one batched attribute read per node. Subtrees outside the visible
    /// clip are skipped. `visit` receives the context its parent returned and returns the
    /// context for the node's children, or nil to skip them.
    static func walk<Context>(
        _ root: AXUIElement, context: Context, visit: (Node, CGRect, Context) -> Context?
    ) {
        let screens = NSScreen.screens.map {
            Geometry.accessibilityFrame(
                ofScreenFrame: $0.frame, primaryScreenHeight: primaryScreenHeight)
        }
        let desktop = screens.reduce(CGRect.null) { $0.union($1) }
        // Each element with the clip and context its parent passes on, and the parent's frame.
        var stack: [(AXUIElement, CGRect, Context, CGRect?)] = [(root, desktop, context, nil)]
        var visited = 0

        while let (element, parentClip, parentContext, parentFrame) = stack.popLast(),
            visited < maxNodes
        {
            visited += 1
            let values = AX.attributes(element, nodeAttributes)
            let node = Node(
                element: element,
                role: values[0] as? String,
                subrole: values[1] as? String,
                frame: AX.frame(position: values[2], size: values[3]),
                enabled: values[4] as? Bool,
                hasChildren: !((values[5] as? [AXUIElement])?.isEmpty ?? true)
            )
            var clip = parentClip
            if let frame = node.frame, frame.width > 0, frame.height > 0 {
                // Out of view, with everything inside it. Unless it is not even inside its
                // parent: then its frame is wrong (DuckDuckGo reports the group around its web
                // view in window coordinates), and its children are judged on their own.
                let misplaced = parentFrame.map { !$0.intersects(frame) } ?? false
                if !frame.intersects(parentClip) && !misplaced { continue }
                if Roles.clipping.contains(node.role ?? "") && !misplaced {
                    clip = frame.intersection(parentClip)
                }
            }
            guard let childContext = visit(node, clip, parentContext),
                var children = values[5] as? [AXUIElement]
            else { continue }
            // Mail's message list has a row per message, 16,000 of them: walking them all
            // used up `maxNodes` before the message view was reached. Only the rows in view
            // matter, plus the header with its column buttons.
            if children.count > 200, node.role == "AXTable" || node.role == "AXOutline",
                let rows = AX.attribute(element, "AXVisibleRows", as: [AXUIElement].self)
            {
                children = rows + [AX.element(element, "AXHeader")].compactMap { $0 }
            }
            // Reversed so that children are visited in document order.
            let frame =
                node.frame.flatMap { $0.width > 0 && $0.height > 0 ? $0 : nil } ?? parentFrame
            stack.append(contentsOf: children.reversed().map { ($0, clip, childContext, frame) })
        }
        if !stack.isEmpty {
            Log.modes.info("walk stopped at \(maxNodes) elements, \(stack.count) left unvisited")
        }
    }

    static func isUsable(_ frame: CGRect, clip: CGRect) -> Bool {
        let visible = frame.intersection(clip)
        return !visible.isNull && visible.width >= 2 && visible.height >= 2
    }

    static func deduplicated(_ targets: [Target]) -> [Target] {
        var seen = Set<String>()
        return targets.filter { target in
            let f = target.frame
            return seen.insert("\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))")
                .inserted
        }
    }

    static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }
}
