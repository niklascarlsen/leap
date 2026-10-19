import AppKit
import ApplicationServices
import LeapCore

@MainActor
extension ElementFinder {
    // MARK: Menu bar

    /// Leap's own status item, labelled from its window since Leap cannot ask itself.
    static weak var ownStatusItem: NSStatusBarButton?

    /// Status items (battery, clock, third-party icons) live in the `AXExtrasMenuBar` of the
    /// process that owns them, so every running app is asked, all at once since some answer
    /// slowly. Leap's own item comes from its window: its main thread is busy asking.
    static func menuExtras(in strip: CGRect) -> [Target] {
        let pids = NSWorkspace.shared.runningApplications.map(\.processIdentifier).filter {
            $0 != getpid()
        }
        var items = concurrentMap(pids) { menuExtraItems(of: $0) }.flatMap { $0 }
        if let button = ownStatusItem, let window = button.window {
            // The window reaches above and below the menu bar; the button is what is drawn.
            let onScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
            let frame = Geometry.accessibilityFrame(
                ofScreenFrame: onScreen, primaryScreenHeight: primaryScreenHeight)
            items.append(
                Target(
                    element: AXUIElementCreateApplication(getpid()), frame: frame,
                    activation: .mouse, name: "Leap"))
        }
        // Items that do not fit, or that a menu bar manager hides, are parked elsewhere.
        return items.filter { strip.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
    }

    /// Menu extras are `AXMenuBarItem`s, directly in the extras menu bar or, for the system's
    /// own items (owned by MenuBarAgent on macOS 27), one level down in a hosting group.
    private nonisolated static func menuExtraItems(of pid: pid_t) -> [Target] {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.1)
        guard let extras = AX.element(appElement, "AXExtrasMenuBar") else { return [] }
        func items(in elements: [AXUIElement], depth: Int) -> [Target] {
            elements.flatMap { element -> [Target] in
                let values = AX.attributes(
                    element, [kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute])
                if values[0] as? String == "AXMenuBarItem" {
                    guard let frame = AX.frame(position: values[1], size: values[2]) else {
                        return []
                    }
                    return [Target(element: element, frame: frame, activation: .mouse)]
                }
                return depth > 0 ? items(in: AX.children(element), depth: depth - 1) : []
            }
        }
        return items(in: AX.children(extras), depth: 1)
    }

    /// The first accessibility request to a process costs about 20 ms, later ones much less,
    /// so the first look for status items is slow. Doing it once at launch keeps that out of
    /// the first leap mode.
    @concurrent nonisolated static func warmUpMenuExtras() async {
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != getpid() {
            _ = menuExtraItems(of: app.processIdentifier)
        }
    }

    /// With "automatically hide the menu bar" the primary screen reserves no space for it,
    /// and labelling its invisible items would only clutter the top of the screen.
    static var isMenuBarVisible: Bool {
        guard let primary = NSScreen.screens.first else { return false }
        if primary.visibleFrame.maxY < primary.frame.maxY { return true }
        // Auto-hidden, but it may be revealed right now (🌐C, or the pointer at the top).
        // Its frame is reported the same either way, so ask what is drawn at the top edge.
        var hit: AXUIElement?
        let point = CGPoint(x: primary.frame.minX + 20, y: 2)
        guard
            AXUIElementCopyElementAtPosition(
                AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit)
                == .success,
            let hit
        else { return false }
        let role = AX.attribute(hit, kAXRoleAttribute, as: String.self) ?? "-"
        Log.modes.info("menu bar hit test: \(role, privacy: .public)")
        return role == "AXMenuBar" || role == "AXMenuBarItem" || role == "AXMenu"
    }
}
