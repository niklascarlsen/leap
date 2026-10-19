import AppKit
import ApplicationServices
import LeapCore

@MainActor
extension ElementFinder {
    // MARK: Scroll areas

    static func scrollAreas(in app: NSRunningApplication) -> [CGRect] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.5)
        // Electron apps only build their accessibility tree when an assistive client asks for it.
        AX.setAttribute(appElement, "AXManualAccessibility", kCFBooleanTrue)
        guard let window = AX.element(appElement, kAXFocusedWindowAttribute) else { return [] }

        var areas: [CGRect] = []
        // Regions in web content that may scroll (see `ScrollAreas`): their frames, the parts
        // of them in view, and how many squeezed-away elements sit on their edges.
        var regions: [(frame: CGRect, visible: CGRect)] = []
        var squeezed: [Int: Int] = [:]
        // Inside web content, the indices in `regions` of a node's ancestors.
        struct Scope {
            var webAncestors: [Int]?
            /// How many scroll areas the node is in.
            var scrollDepth = 0
        }
        walk(window, context: Scope()) { node, clip, scope in
            guard let frame = node.frame else { return scope }
            var scope = scope
            // Inside another scroll area, content sized to fit (each message's body in a
            // Mail thread) does not scroll: a scroll area there counts only with a scroll
            // bar, and a web area only in its own scroll area, as a browser's page is.
            // Outermost ones count anyway: Chromium's page has no scroll bar in the tree.
            if node.role == Roles.webArea {
                if scope.scrollDepth <= 1 { areas.append(frame.intersection(clip)) }
            } else if node.role == Roles.scrollArea {
                if scope.scrollDepth == 0 || hasScrollBar(node.element) {
                    areas.append(frame.intersection(clip))
                }
                scope.scrollDepth += 1
            }
            guard var ancestors = scope.webAncestors ?? (node.role == Roles.webArea ? [] : nil)
            else { return scope }
            if ScrollAreas.isCollapsed(frame, hasContent: node.hasChildren) {
                if let clipper = ScrollAreas.clipper(
                    of: frame, among: ancestors.map { regions[$0].frame })
                {
                    // Squeezed content usually has text inside; a separator line has nothing.
                    squeezed[ancestors[clipper], default: 0] += node.hasChildren ? 2 : 1
                }
                // Everything inside is scrolled away too.
                return nil
            }
            if frame.width >= ScrollAreas.minimumSide, frame.height >= ScrollAreas.minimumSide {
                ancestors.append(regions.count)
                regions.append((frame, frame.intersection(clip)))
            }
            scope.webAncestors = ancestors
            return scope
        }
        // Two or more, so a lone separator line on an edge does not count; a squeezed
        // element with something inside counts as two on its own.
        areas += squeezed.filter { $0.value >= 2 }.keys.sorted().map { regions[$0].visible }
        areas.removeAll {
            $0.isNull || $0.width < ScrollAreas.minimumSide || $0.height < ScrollAreas.minimumSide
        }
        Log.modes.debug(
            "scroll areas: \(regions.count) web regions checked, \(squeezed.count) with content squeezed away"
        )

        // Web areas usually sit inside an equally sized scroll area; keep one of each size.
        var seen = Set<String>()
        let unique = areas.filter {
            seen.insert("\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width)),\(Int($0.height))")
                .inserted
        }
        if !unique.isEmpty { return ScrollAreas.withoutCovered(unique) }

        // Apps that draw everything themselves (terminals such as WezTerm, games, canvas
        // apps) show no scroll areas, but scroll events still reach whatever is under the
        // cursor; so the window itself is the one area.
        let desktop = NSScreen.screens.reduce(CGRect.null) {
            $0.union(
                Geometry.accessibilityFrame(
                    ofScreenFrame: $1.frame, primaryScreenHeight: primaryScreenHeight))
        }
        guard let frame = AX.frame(of: window)?.intersection(desktop),
            frame.width >= ScrollAreas.minimumSide, frame.height >= ScrollAreas.minimumSide
        else { return [] }
        Log.modes.debug("scroll areas: none in the window, using the window")
        return [frame]
    }

    private static func hasScrollBar(_ scrollArea: AXUIElement) -> Bool {
        AX.attributes(scrollArea, [kAXVerticalScrollBarAttribute, kAXHorizontalScrollBarAttribute])
            .contains {
                $0 != nil
            }
    }
}
