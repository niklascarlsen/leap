import AppKit

/// Calls back on any mouse button press anywhere, so a mode can close when the user
/// reaches for the mouse. The click itself still goes through to its target.
@MainActor
final class MouseDownWatcher {
    private var monitor: Any?

    func start(_ onMouseDown: @escaping @MainActor () -> Void) {
        stop()
        // Leap's overlay ignores the mouse, so every click lands in another app and is
        // reported to a global monitor. Monitors run on the main thread.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
        ]) { _ in
            MainActor.assumeIsolated { onMouseDown() }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
