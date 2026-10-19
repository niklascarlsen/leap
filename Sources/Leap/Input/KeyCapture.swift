import AppKit
import CoreGraphics

/// Captures keyboard input globally with a `CGEventTap` while a mode is active, so the
/// frontmost app keeps focus and never sees the keys Leap consumes.
@MainActor
final class KeyCapture {
    /// Return true to swallow the event.
    typealias Handler = (KeyPress) -> Bool

    private var tap: EventTap?
    private var handler: Handler?

    func start(_ handler: @escaping Handler) -> Bool {
        stop()
        self.handler = handler
        tap = EventTap(
            events: [.keyDown, .keyUp], callback: keyCaptureCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        return tap != nil
    }

    func stop() {
        tap?.stop()
        tap = nil
        handler = nil
    }

    fileprivate func reenable() {
        tap?.reenable()
    }

    fileprivate func handle(_ press: KeyPress) -> Bool {
        // Let Leap's own shortcuts through so they can toggle the running mode.
        if HotKeys.shared.matches(press) { return false }
        return handler?(press) ?? false
    }
}

private func keyCaptureCallback(
    _: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let capture = Unmanaged<KeyCapture>.fromOpaque(userInfo).takeUnretainedValue()
    // The tap's run loop source is on the main run loop, so the main actor is current.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { capture.reenable() }
        return Unmanaged.passUnretained(event)
    }
    guard let press = KeyPress(type: type, event: event) else {
        return Unmanaged.passUnretained(event)
    }
    let swallow = MainActor.assumeIsolated { capture.handle(press) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
