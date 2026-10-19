import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Menu bar agent: no Dock icon, never steals focus on launch.
    app.setActivationPolicy(.accessory)
    app.run()
}
