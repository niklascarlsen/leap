import AppKit
import ApplicationServices
import LeapCore

@MainActor
extension ElementFinder {
    // MARK: Mission Control

    /// On macOS 27 Mission Control lives in WindowManager as `mc.display` groups of window buttons.
    static func missionControlTargets() -> [Target]? {
        guard let windowManager = NSRunningApplication.running("com.apple.WindowManager") else {
            return nil
        }
        let pid = windowManager.processIdentifier
        let wmElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(wmElement, 0.5)
        let children = AX.children(wmElement)
        var displays = children.filter { identifier($0) == "mc.display" }
        if displays.isEmpty {
            // The Dock keeps an empty `mc` placeholder only while Mission Control is open;
            // without it there is nothing to find, so skip the slower hit test.
            guard dockHasMissionControlPlaceholder() else { return nil }
            displays = missionControlDisplaysByHitTest(windowManagerPid: pid)
        }
        Log.modes.info(
            """
            mission control check: WindowManager children \(children.map { identifier($0) ?? "-" }, privacy: .public), \
            displays found \(displays.count)
            """)
        guard !displays.isEmpty else { return nil }

        var targets: [Target] = []
        for display in displays {
            walk(display) { node, clip in
                if node.role == "AXGroup", identifier(node.element) == "mc.spaces" {
                    targets += spacesBarTargets(node.element)
                    return false
                }
                // AXPress on a window thumbnail only dismisses Mission Control without bringing
                // that window forward (macOS 27), so these get a real click.
                if node.role == "AXButton", let frame = node.frame, isUsable(frame, clip: clip) {
                    targets.append(
                        Target(
                            element: node.element, frame: frame.intersection(clip),
                            activation: .mouse))
                }
                return true
            }
        }
        targets = placed(targets)
        targets += dockTargets()
        return inReadingOrder(targets)
    }

    /// The Spaces bar along the top. Its items report their center as their position
    /// (macOS 27). Folded, it shows only the desktops' names, at the bottom of where their
    /// pictures would be. The button that adds a desktop sits just past the right screen edge,
    /// where only its plus sign shows until the pointer comes near. All of them are pressed:
    /// the bar unfolds under the pointer, and a click lands while it moves.
    private static func spacesBarTargets(_ bar: AXUIElement) -> [Target] {
        guard let barFrame = AX.frame(of: bar), let screen = screenFrame(containing: barFrame)
        else { return [] }
        let items = AX.children(bar).flatMap {
            identifier($0) == "mc.spaces.list" ? AX.children($0) : [$0]
        }
        return items.compactMap { item in
            let values = AX.attributes(
                item,
                [kAXRoleAttribute, kAXIdentifierAttribute, kAXPositionAttribute, kAXSizeAttribute])
            guard values[0] as? String == "AXButton",
                let reported = AX.frame(position: values[2], size: values[3])
            else { return nil }
            let frame = reported.offsetBy(dx: -reported.width / 2, dy: -reported.height / 2)
            if values[1] as? String == "mc.spaces.add" {
                // Folded, the button is centered above the screen; the plus sign is in the bar.
                let rows = frame.minY >= barFrame.minY ? frame : barFrame
                let plus = CGRect(x: screen.maxX - 60, y: rows.minY, width: 60, height: rows.height)
                return Target(element: item, frame: plus, activation: .press)
            }
            let visible = frame.intersection(barFrame)
            guard isUsable(visible, clip: screen) else { return nil }
            return Target(
                element: item, frame: visible.intersection(screen), activation: .press,
                shiftAction: "AXRemoveDesktop")
        }
    }

    /// Mission Control lists the windows of every desktop but shows only the current one's,
    /// so window thumbnails without a window here are dropped. It also moves every window
    /// from where it is to its thumbnail, and slides the Spaces bar in from the screen edge.
    /// Knowing where each target starts lets its label move along instead of waiting at the
    /// end.
    private static func placed(_ targets: [Target]) -> [Target] {
        var targets = targets
        var thumbnails: [String: [(index: Int, title: String)]] = [:]
        for index in targets.indices {
            let values = AX.attributes(
                targets[index].element, [kAXIdentifierAttribute, kAXTitleAttribute])
            // Window thumbnails are identified as "<bundle id>.space.<n>".
            if let identifier = values[0] as? String,
                let range = identifier.range(of: ".space.", options: .backwards)
            {
                thumbnails[String(identifier[..<range.lowerBound]), default: []]
                    .append((index, values[1] as? String ?? ""))
            } else if let screen = screenFrame(containing: targets[index].frame) {
                targets[index].appearsFrom = MissionControlMotion.slideStart(
                    of: targets[index].frame, in: screen)
            }
        }
        var elsewhere = IndexSet()
        // A window of a process without a bundle (a second WezTerm started from a shell) is
        // identified as ".space.<n>" and cannot be looked up; it stays.
        for (bundle, shown) in thumbnails where !bundle.isEmpty {
            let windows = standardWindows(of: bundle)
            let matches = MissionControlMotion.thumbnails(
                titled: shown.map(\.title), windowTitles: windows.map(\.title))
            for ((index, _), match) in zip(shown, matches) {
                switch match {
                case .window(let window): targets[index].appearsFrom = windows[window].frame
                case .unmatched: break
                case .otherDesktop:
                    Log.modes.info(
                        "mission control: thumbnail \(index) is on another desktop")
                    elsewhere.insert(index)
                }
            }
        }
        return targets.indices.filter { !elsewhere.contains($0) }.map { targets[$0] }
    }

    private static func standardWindows(of bundle: String) -> [(title: String, frame: CGRect)] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundle).flatMap { app in
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.1)
            let windows =
                AX.attribute(appElement, kAXWindowsAttribute, as: [AXUIElement].self) ?? []
            return windows.compactMap { window -> (title: String, frame: CGRect)? in
                let values = AX.attributes(
                    window,
                    [
                        kAXSubroleAttribute, kAXMinimizedAttribute, kAXTitleAttribute,
                        kAXPositionAttribute,
                        kAXSizeAttribute,
                    ])
                guard values[0] as? String == kAXStandardWindowSubrole, values[1] as? Bool != true,
                    let frame = AX.frame(position: values[3], size: values[4])
                else { return nil }
                return (values[2] as? String ?? "", frame)
            }
        }
    }

    private static func screenFrame(containing rect: CGRect) -> CGRect? {
        NSScreen.screens
            .map {
                Geometry.accessibilityFrame(
                    ofScreenFrame: $0.frame, primaryScreenHeight: primaryScreenHeight)
            }
            .first { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) }
    }

    /// Cheap check (one IPC round trip) used by the Mission Control watcher.
    static func isMissionControlOpen() -> Bool {
        guard let windowManager = NSRunningApplication.running("com.apple.WindowManager") else {
            return false
        }
        let wmElement = AXUIElementCreateApplication(windowManager.processIdentifier)
        AXUIElementSetMessagingTimeout(wmElement, 0.3)
        return AX.children(wmElement).contains { identifier($0) == "mc.display" }
    }

    /// Depending on how Mission Control was opened, WindowManager may not list `mc.display`
    /// among its children. Hit-testing the middle of each screen finds whatever WindowManager
    /// draws there; climbing parents from it reaches the display group.
    private static func missionControlDisplaysByHitTest(windowManagerPid: pid_t) -> [AXUIElement] {
        let systemWide = AXUIElementCreateSystemWide()
        var displays: [AXUIElement] = []
        for screen in NSScreen.screens {
            let frame = Geometry.accessibilityFrame(
                ofScreenFrame: screen.frame, primaryScreenHeight: primaryScreenHeight)
            var hit: AXUIElement?
            guard
                AXUIElementCopyElementAtPosition(
                    systemWide, Float(frame.midX), Float(frame.midY), &hit) == .success,
                var element = hit
            else { continue }
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            Log.modes.info(
                """
                mission control hit test: pid \(pid) (WindowManager \(windowManagerPid)), \
                identifier \(identifier(element) ?? "-", privacy: .public)
                """)
            guard pid == windowManagerPid else { continue }
            for _ in 0..<8 {
                if identifier(element) == "mc.display" {
                    displays.append(element)
                    break
                }
                guard let parent = AX.element(element, kAXParentAttribute) else { break }
                element = parent
            }
        }
        return displays
    }

    private static func dockHasMissionControlPlaceholder() -> Bool {
        guard let dock = NSRunningApplication.running("com.apple.dock") else { return false }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(dockElement, 0.3)
        return AX.children(dockElement).contains { identifier($0) == "mc" }
    }

    private static func identifier(_ element: AXUIElement) -> String? {
        AX.attribute(element, kAXIdentifierAttribute, as: String.self)
    }

    /// Dock items, pressed with `AXPress`. An auto-hidden Dock slides in when Mission Control
    /// opens, and when Leap looks it may still be hidden or halfway, so where it ends up is
    /// worked out from the Dock's settings. LeapMode reads the real frames once Mission
    /// Control has settled.
    private static func dockTargets() -> [Target] {
        guard let dock = NSRunningApplication.running("com.apple.dock") else { return [] }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(dockElement, 0.5)
        let screens = NSScreen.screens.map {
            Geometry.accessibilityFrame(
                ofScreenFrame: $0.frame, primaryScreenHeight: primaryScreenHeight)
        }
        let settings = UserDefaults(suiteName: "com.apple.dock")
        let autohides = settings?.bool(forKey: "autohide") ?? false
        let orientation = settings?.string(forKey: "orientation") ?? "bottom"
        var targets: [Target] = []
        for list in AX.children(dockElement)
        where AX.attribute(list, kAXRoleAttribute, as: String.self) == "AXList" {
            for item in AX.children(list) {
                let values = AX.attributes(
                    item,
                    [kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute])
                guard values[0] as? String == "AXDockItem",
                    values[1] as? String != "AXSeparatorDockItem",
                    let frame = AX.frame(position: values[2], size: values[3])
                else { continue }
                // Each item on its own: the Dock may move between reads.
                let shift =
                    autohides
                    ? shownDockShift(frame, orientation: orientation, screens: screens) : .zero
                let shown = frame.offsetBy(dx: shift.dx, dy: shift.dy)
                guard screens.contains(where: { isUsable(shown, clip: $0) }) else { continue }
                targets.append(
                    Target(
                        element: item, frame: shown, activation: .press, appearsFrom: frame,
                        inDock: true))
            }
        }
        return targets
    }

    /// How far an item of an auto-hidden Dock still has to move to be shown: in Mission
    /// Control the items end 5 points in from their screen edge (measured on macOS 27).
    private static func shownDockShift(_ dock: CGRect, orientation: String, screens: [CGRect])
        -> CGVector
    {
        let margin: CGFloat = 5
        let center = CGPoint(x: dock.midX, y: dock.midY)
        switch orientation {
        case "left":
            guard
                let screen = screens.filter({ $0.minY <= center.y && center.y < $0.maxY })
                    .min(by: { abs($0.minX - dock.minX) < abs($1.minX - dock.minX) })
            else { return .zero }
            return CGVector(dx: screen.minX + margin - dock.minX, dy: 0)
        case "right":
            guard
                let screen = screens.filter({ $0.minY <= center.y && center.y < $0.maxY })
                    .min(by: { abs($0.maxX - dock.maxX) < abs($1.maxX - dock.maxX) })
            else { return .zero }
            return CGVector(dx: screen.maxX - margin - dock.maxX, dy: 0)
        default:
            guard
                let screen = screens.filter({ $0.minX <= center.x && center.x < $0.maxX })
                    .min(by: { abs($0.maxY - dock.maxY) < abs($1.maxY - dock.maxY) })
            else { return .zero }
            return CGVector(dx: 0, dy: screen.maxY - margin - dock.maxY)
        }
    }
}
