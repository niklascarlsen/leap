import AppKit
import ApplicationServices
import LeapCore

@MainActor
extension ElementFinder {
    // MARK: Click targets

    static func clickTargets(in app: NSRunningApplication) -> [Target] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.5)
        // Electron apps only build their accessibility tree when an assistive client asks for it.
        AX.setAttribute(appElement, "AXManualAccessibility", kCFBooleanTrue)

        var inWindow: [Target] = []
        if let window = AX.element(appElement, kAXFocusedWindowAttribute) {
            inWindow = clickables(under: window)
        }
        // Banners are drawn over the window, so what they cover cannot be clicked.
        let inNotifications = notifications()
        inWindow.removeAll { target in
            inNotifications.contains { $0.frame.contains(Geometry.center(of: target.frame)) }
        }
        var inMenuBar: [Target] = []
        if isMenuBarVisible, let menuBar = AX.element(appElement, kAXMenuBarAttribute) {
            inMenuBar = clickables(under: menuBar)
            if let strip = AX.frame(of: menuBar) { inMenuBar += menuExtras(in: strip) }
        }
        // The shortest labels go to the window, the rest get what is left.
        return [inWindow, inNotifications, inMenuBar].flatMap {
            inReadingOrder(withoutNoise(deduplicated($0)))
        }
    }

    /// Leap's own window (Settings), read in-process: asking Leap through the accessibility
    /// API from its own main thread would wait for itself. SwiftUI's elements implement the
    /// accessibility methods without declaring `NSAccessibilityProtocol`, so they are asked
    /// by name.
    static func ownWindowTargets() -> [Target] {
        guard let window = NSApp.keyWindow, window.isVisible else { return [] }
        func value<T>(_ object: NSObject, _ getter: String, key: String? = nil, as _: T.Type) -> T?
        {
            guard object.responds(to: NSSelectorFromString(getter)) else { return nil }
            return object.value(forKey: key ?? getter) as? T
        }
        var found: [Target] = []
        func visit(_ object: Any, depth: Int) {
            guard depth < 40, let object = object as? NSObject else { return }
            let role = value(object, "accessibilityRole", as: String.self) ?? ""
            if Roles.clickable.contains(role),
                value(object, "isAccessibilityElement", key: "accessibilityElement", as: Bool.self)
                    ?? false,
                value(object, "isAccessibilityEnabled", key: "accessibilityEnabled", as: Bool.self)
                    ?? true,
                let screenFrame = value(object, "accessibilityFrame", as: NSValue.self)?.rectValue
            {
                let frame = Geometry.accessibilityFrame(
                    ofScreenFrame: screenFrame, primaryScreenHeight: primaryScreenHeight)
                let label = value(object, "accessibilityLabel", as: String.self)
                let title = value(object, "accessibilityTitle", as: String.self)
                let name = [label, title].compactMap { $0 }.first { !$0.isEmpty } ?? role
                let press: @MainActor () -> Void = {
                    // A click would jump a slider to where it lands; focused, the arrow keys move it.
                    if role == "AXSlider",
                        object.responds(to: NSSelectorFromString("setAccessibilityFocused:"))
                    {
                        object.setValue(true, forKey: "accessibilityFocused")
                    } else if let element = object as? NSAccessibilityProtocol {
                        _ = element.accessibilityPerformPress()
                    } else if object.responds(to: NSSelectorFromString("accessibilityPerformPress"))
                    {
                        _ = object.perform(NSSelectorFromString("accessibilityPerformPress"))
                    }
                }
                // Pressing a text field does nothing; the click puts the caret in it.
                let isText = role == "AXTextField" || role == "AXTextArea"
                found.append(
                    Target(
                        element: AXUIElementCreateApplication(getpid()), frame: frame,
                        activation: .mouse, name: name,
                        pressInProcess: isText ? nil : press
                    ))
            }
            for child in value(object, "accessibilityChildren", as: [Any].self) ?? [] {
                visit(child, depth: depth + 1)
            }
        }
        visit(window, depth: 0)
        // SwiftUI's ColorPicker leaves its color well out of the accessibility tree.
        func colorWells(in view: NSView) -> [NSColorWell] {
            view.subviews.flatMap { ($0 as? NSColorWell).map { [$0] } ?? colorWells(in: $0) }
        }
        for well in colorWells(in: window.contentView ?? NSView())
        where !well.isHiddenOrHasHiddenAncestor && well.isEnabled {
            let screenFrame = window.convertToScreen(well.convert(well.bounds, to: nil))
            let frame = Geometry.accessibilityFrame(
                ofScreenFrame: screenFrame, primaryScreenHeight: primaryScreenHeight)
            found.append(
                Target(
                    element: AXUIElementCreateApplication(getpid()), frame: frame,
                    activation: .mouse,
                    name: "color well",
                    pressInProcess: { _ = well.accessibilityPerformPress() }
                ))
        }
        return inReadingOrder(withoutNoise(deduplicated(found)))
    }

    /// Slivers too thin to aim at, such as a button scrolled almost out of view.
    private static func withoutNoise(_ targets: [Target]) -> [Target] {
        targets.filter { $0.frame.width >= minimumSide && $0.frame.height >= minimumSide }
    }
    private static let minimumSide: CGFloat = 8

    private static func clickables(under root: AXUIElement) -> [Target] {
        var targets: [Target] = []
        var fromWebArea = IndexSet()
        // Which target each visited element belongs to, and each target's labelled ancestor,
        // so hit tests can be attributed to targets without asking the app for parents.
        var owner: [ElementKey: Int] = [:]
        var parentTarget: [Int?] = []
        var roles: [String] = []
        var isUIKit = false
        // The walk context is the index (in `targets`) of the nearest labelled ancestor.
        walk(root, context: Int?.none) { node, clip, labelledAncestor in
            let role = node.role ?? ""
            // The window's first child, so it is seen before any content.
            if node.subrole == "iOSContentGroup" { isUIKit = true }
            if role == Roles.webArea, let found = searchPredicate(in: node.element, clip: clip) {
                fromWebArea.insert(integersIn: targets.count..<targets.count + found.count)
                targets += found
                parentTarget += Array(repeating: labelledAncestor, count: found.count)
                roles += Array(repeating: "", count: found.count)
                return nil
            }
            func belongsToAncestor() -> Int? {
                if let labelledAncestor { owner[ElementKey(node.element)] = labelledAncestor }
                return labelledAncestor
            }
            // PDFKit (Preview) answers `AXEnabled` false for every link in a PDF, an attribute
            // its links do not even list. Links have no disabled state, so it is ignored there.
            let enabled = node.enabled != false || role == "AXLink"
            guard enabled, let frame = node.frame, isUsable(frame, clip: clip) else {
                return belongsToAncestor()
            }
            let clickable =
                if let labelledAncestor {
                    // A text field in a row is its editable title (Mail's own mailboxes): clicking
                    // the row is what selects it.
                    Roles.nestedControls.contains(role)
                        && !(role == "AXTextField" && roles[labelledAncestor] == "AXRow")
                } else {
                    Roles.clickable.contains(role)
                        || ((Roles.clickableByAction.contains(role)
                            || isUIKit && Roles.clickableByActionInUIKit.contains(role))
                            && hasClickAction(node.element))
                }
            guard clickable, !(role == "AXRow" && isGroupHeader(node.element)) else {
                return belongsToAncestor()
            }

            let target = Target(
                element: node.element, frame: frame.intersection(clip), activation: .mouse)
            // A control at the leading edge of its labelled row (System Settings' sidebar) is
            // the same visual item: one label, placed like the row's so a sidebar stays
            // consistent. Controls elsewhere in the row (Finder's eject button) keep their own.
            if let ancestor = labelledAncestor,
                startsTogether(target.frame, targets[ancestor].frame)
            {
                targets[ancestor] = Target(
                    element: node.element, frame: targets[ancestor].frame, activation: .mouse)
                roles[ancestor] = role
                owner[ElementKey(node.element)] = ancestor
                return ancestor
            }
            targets.append(target)
            parentTarget.append(labelledAncestor)
            roles.append(role)
            owner[ElementKey(node.element)] = targets.count - 1
            // A menu bar item's children are its whole closed menu, nothing to label.
            return role == "AXMenuBarItem" ? nil : targets.count - 1
        }
        guard isUIKit else { return targets }

        // iOS apps on the Mac lay content out under sidebars and bars and rely on insets, so
        // frames can reach under other views: WhatsApp's chat rows start at the window edge,
        // beneath its sidebar, and their labels landed on the sidebar. Hit-testing the label
        // spot tells what is really drawn there.
        let started = Date.now
        func target(_ index: Int, owns hit: AXUIElement?) -> Bool {
            guard let hit else { return true }
            var current = owner[ElementKey(hit)]
            while let candidate = current {
                if candidate == index { return true }
                current = parentTarget[candidate]
            }
            return false
        }
        let candidates = targets.indices.filter { !fromWebArea.contains($0) }
        let frames = candidates.map { targets[$0].frame }
        let starts = VisibleStart.find(in: frames) { probes in
            let hits = elements(at: probes.map { CGPoint(x: $0.x, y: frames[$0.index].midY) })
            return zip(probes, hits).map { target(candidates[$0.index], owns: $1) }
        }
        for (index, minX) in zip(candidates, starts) {
            guard let minX else { continue }
            let frame = targets[index].frame
            let visible = CGRect(
                x: minX, y: frame.minY, width: frame.maxX - minX, height: frame.height)
            targets[index] = Target(
                element: targets[index].element, frame: visible,
                activation: targets[index].activation)
        }
        Log.modes.debug(
            "UIKit window: visible starts checked in \(Int(Date.now.timeIntervalSince(started) * 1000)) ms"
        )
        return targets
    }

    /// Hit-tests many points at once. The app answers one at a time, but overlapping the round
    /// trips still makes a batch about twice as fast as asking in turn.
    private nonisolated static func elements(at points: [CGPoint]) -> [AXUIElement?] {
        concurrentMap(points) { point in
            var hit: AXUIElement?
            let systemWide = AXUIElementCreateSystemWide()
            guard
                AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit)
                    == .success
            else { return nil }
            return hit
        }
    }

    /// Lets accessibility elements key a dictionary; equal elements are the same UI object.
    private struct ElementKey: Hashable {
        let element: AXUIElement
        init(_ element: AXUIElement) { self.element = element }
        static func == (lhs: Self, rhs: Self) -> Bool { CFEqual(lhs.element, rhs.element) }
        func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
    }

    private static func startsTogether(_ inner: CGRect, _ outer: CGRect) -> Bool {
        inner.minX - outer.minX < 48 && abs(inner.midY - outer.midY) < max(inner.height, 12)
    }

    /// Group headers in outlines ("Favorites" in Finder's sidebar) are rows that disclose
    /// other rows but, unlike folders in a list view, have no actionable cell.
    private static func isGroupHeader(_ row: AXUIElement) -> Bool {
        guard let disclosed = AX.attribute(row, "AXDisclosedRows", as: [AXUIElement].self),
            !disclosed.isEmpty
        else { return false }
        return !AX.children(row).contains { hasClickAction($0) }
    }

    private static func hasClickAction(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
            let names = names as? [String]
        else {
            return false
        }
        return names.contains { Roles.clickActions.contains($0) }
    }

    /// Browsers answer this private search in one call instead of a walk over thousands of nodes.
    private static func searchPredicate(in webArea: AXUIElement, clip: CGRect) -> [Target]? {
        let predicate: [String: Any] = [
            "AXSearchKey": [
                "AXButtonSearchKey", "AXCheckBoxSearchKey", "AXControlSearchKey", "AXLinkSearchKey",
                "AXRadioGroupSearchKey", "AXTextFieldSearchKey", "AXKeyboardFocusableSearchKey",
            ],
            "AXResultsLimit": -1,
            "AXVisibleOnly": true,
            "AXDirection": "AXDirectionNext",
            "AXImmediateDescendantsOnly": false,
        ]
        guard
            let answer = AX.parameterized(
                webArea, "AXUIElementsForSearchPredicate", predicate as CFDictionary)
                as? [AnyObject]
        else { return nil }
        // Newer Chromium (Claude's Electron) wraps each result as {AXSearchResultElement: element}.
        let results = answer.compactMap { result -> AXUIElement? in
            let element = (result as? [String: AnyObject])?["AXSearchResultElement"] ?? result
            guard CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
            return (element as! AXUIElement)
        }
        // Answers in a shape not known here: walking the web area is slower but still works.
        guard !results.isEmpty else { return nil }
        let found = results.compactMap { element -> (target: Target, role: String?)? in
            let values = AX.attributes(
                element,
                [kAXPositionAttribute, kAXSizeAttribute, kAXEnabledAttribute, kAXRoleAttribute])
            guard (values[2] as? Bool) != false,
                let frame = AX.frame(position: values[0], size: values[1]),
                isUsable(frame, clip: clip)
            else { return nil }
            return (
                Target(element: element, frame: frame.intersection(clip), activation: .mouse),
                values[3] as? String
            )
        }
        // Pages make headings, cards and whole regions focusable; labelling those only
        // doubles up on the links and buttons inside them.
        let wrappers = Set(
            LabelLayout.wrappers(in: found.map(\.target.frame)).filter {
                Roles.wrappers.contains(found[$0].role ?? "")
            }
        )
        return found.indices.filter { !wrappers.contains($0) }.map { found[$0].target }
    }
}
