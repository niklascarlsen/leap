import AppKit
import ApplicationServices
import LeapCore

/// Reports when Mission Control opens and closes.
///
/// On macOS 27 the Dock no longer posts its `AXExpose*` notifications, but it still posts
/// `AXSelectedChildrenChanged` when Mission Control opens or closes. That only says that
/// *something* changed, so every notification triggers a few checks for WindowManager's
/// `mc.display` group while the Mission Control animation settles.
///
/// The Dock only posts once the opening animation is over, about half a second after the
/// shortcut, while `mc.display` exists within 30 ms. So pressing the Mission Control
/// shortcut (`expectChange`) also starts checks every 10 ms.
@MainActor
final class MissionControlWatcher {
    /// Called with the time Mission Control started opening, when that is known.
    var onOpen: ((Date?) -> Void)?
    var onClose: (() -> Void)?
    private(set) var isOpen = false

    private var observer: AXObserver?
    private var checks: Task<Void, Never>?
    private var launchObserver: NSObjectProtocol?
    private var shortcutPressed: Date?
    private var fastChecks: Timer?

    /// The Mission Control shortcut from System Settings > Keyboard > Keyboard Shortcuts.
    static var shortcut: HotKeySpec? { SystemShortcuts.missionControl }

    /// The Mission Control shortcut was pressed: it opens or closes within a few frames.
    func expectChange() {
        let pressed = Date.now
        shortcutPressed = pressed
        let wasOpen = isOpen
        fastChecks?.invalidate()
        fastChecks = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.fastCheck(since: pressed, wasOpen: wasOpen) }
        }
    }

    private func fastCheck(since pressed: Date, wasOpen: Bool) {
        check()
        guard isOpen != wasOpen || Date.now.timeIntervalSince(pressed) > 0.6 else { return }
        fastChecks?.invalidate()
        fastChecks = nil
    }

    func start() {
        subscribeToDock()
        // The Dock restarts after crashes and `killall Dock`; follow it to its new process.
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app =
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == "com.apple.dock" else { return }
            MainActor.assumeIsolated { self?.subscribeToDock() }
        }
    }

    private func subscribeToDock() {
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
            self.observer = nil
        }
        guard let dock = NSRunningApplication.running("com.apple.dock") else {
            Log.app.error("mission control watcher: Dock is not running")
            return
        }
        var observer: AXObserver?
        guard
            AXObserverCreate(dock.processIdentifier, missionControlCallback, &observer) == .success,
            let observer
        else {
            Log.app.error("mission control watcher: could not observe the Dock")
            return
        }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        let result = AXObserverAddNotification(
            observer, dockElement, kAXSelectedChildrenChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
        Log.app.info(
            "mission control watcher: observing Dock pid \(dock.processIdentifier), result \(result.rawValue)"
        )
    }

    fileprivate func dockChanged() {
        checks?.cancel()
        checks = Task { [weak self] in
            let changed = ContinuousClock.now
            for delay in [0.0, 0.15, 0.35, 0.7] {
                do { try await Task.sleep(until: changed + .seconds(delay)) } catch { return }
                self?.check()
            }
        }
    }

    private func check() {
        let open = ElementFinder.isMissionControlOpen()
        guard open != isOpen else { return }
        isOpen = open
        Log.modes.info("mission control \(open ? "opened" : "closed", privacy: .public)")
        guard open else { return onClose?() ?? () }
        // Only a fresh shortcut press tells when the opening animation started.
        let started = shortcutPressed.flatMap { Date.now.timeIntervalSince($0) < 0.6 ? $0 : nil }
        onOpen?(started)
    }
}

private func missionControlCallback(
    _: AXObserver, _: AXUIElement, _: CFString, _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let watcher = Unmanaged<MissionControlWatcher>.fromOpaque(refcon).takeUnretainedValue()
    // The observer's run loop source is on the main run loop.
    MainActor.assumeIsolated { watcher.dockChanged() }
}
