import AppKit
import SwiftUI

/// The Settings window: a General and an Appearance tab in the toolbar, like the system's
/// own apps. Every control writes straight to `UserDefaults`, and the overlays read
/// `Settings` each time they draw, so changes apply immediately.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let tabs = SettingsTabs()
            tabs.tabStyle = .toolbar
            tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", GeneralSettings()))
            tabs.addTabViewItem(
                Self.tab("Appearance", symbol: "paintpalette", AppearanceSettings()))
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.toolbarStyle = .preference
            // Each tab draws Liquid Glass behind itself, reaching under the toolbar.
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        // Leap is a menu bar agent, so it must activate itself to bring a window forward.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        // Nothing starts focused: a focus ring on the first shortcut would read as recording.
        window?.makeFirstResponder(nil)
        // macOS turns that request down when no click went to Leap, as when its menu is
        // opened by a label and the item chosen with the keyboard; the window then stays
        // behind the app in front. Opening Leap through Launch Services is honored, and
        // brings the window forward through `applicationShouldHandleReopen`.
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            reopenIfNotActive()
        }
    }

    private func reopenIfNotActive() {
        guard !NSApp.isActive, lastReopen.map({ Date.now.timeIntervalSince($0) > 2 }) ?? true else {
            return
        }
        Log.app.info("settings: activation declined, reopening Leap")
        lastReopen = Date.now
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
    }

    /// When Leap last reopened itself; the reopen shows the window again, and if that is
    /// declined too, it is not retried in a loop.
    private var lastReopen: Date?

    /// An agent app stays active with no window left, so keys would go nowhere; hiding it
    /// hands the keyboard back to the app that was in front before.
    func windowWillClose(_: Notification) {
        NSApp.hide(nil)
    }

    private static func tab(_ title: String, symbol: String, _ view: some View) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view)
        // The window shows the selected tab's title, takes its size and animates between them.
        controller.title = title
        controller.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
