import AppKit
import ApplicationServices
import LeapCore

@MainActor
extension ElementFinder {
    // MARK: Notifications

    /// Notification banners and alerts on screen, and the buttons on them (answering or
    /// declining a call). Notification Center draws them all in one window over the whole
    /// screen; each is an `AXGroup` whose `AXPress` opens it and whose custom "Close" action,
    /// with Shift, closes it. A banner shows its buttons only while the pointer is over it.
    static func notifications() -> [Target] {
        guard let app = NSRunningApplication.running(notificationCenter) else { return [] }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.1)
        let windows = AX.attribute(appElement, kAXWindowsAttribute, as: [AXUIElement].self) ?? []
        var found: [Target] = []
        for window in windows {
            // The context tells whether the node is inside a notification.
            walk(window, context: false) { node, clip, inNotification -> Bool? in
                // Subroles AXNotificationCenterBanner and AXNotificationCenterAlert.
                let isNotification = node.subrole?.hasPrefix("AXNotificationCenter") == true
                guard isNotification || inNotification else { return false }
                guard node.enabled != false, let frame = node.frame, isUsable(frame, clip: clip)
                else { return nil }
                if isNotification {
                    found.append(
                        Target(
                            element: node.element, frame: frame, activation: .pressOnly,
                            shiftAction: closeAction(of: node.element)))
                } else if Roles.nestedControls.contains(node.role ?? "") {
                    found.append(
                        Target(element: node.element, frame: frame, activation: .pressOnly))
                }
                return true
            }
        }
        return found
    }

    private static let notificationCenter = "com.apple.notificationcenterui"

    /// Custom actions are named in the user's language ("Name:Close\nTarget:…"), so the name
    /// is matched against every translation Notification Center has of it.
    private static func closeAction(of element: AXUIElement) -> String? {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
            let names = names as? [String]
        else { return nil }
        return names.first { name in
            name.hasPrefix("Name:")
                && closeNames.contains(String(name.dropFirst(5).prefix { $0 != "\n" }))
        }
    }

    private static let closeNames: Set<String> = {
        guard
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: notificationCenter)?
                .appending(path: "Contents/Resources/Localizable.loctable"),
            let data = try? Data(contentsOf: url),
            let table = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: [String: Any]]
        else { return ["Close"] }
        return Set(table.values.compactMap { $0["Close"] as? String } + ["Close"])
    }()
}
