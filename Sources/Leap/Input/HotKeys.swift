import CoreGraphics
import LeapCore

/// Global shortcuts via a listening `CGEventTap`.
///
/// Carbon's `RegisterEventHotKey` is not delivered while Mission Control is open, so Leap
/// watches key-down events itself. Only exact matches of registered shortcuts are
/// swallowed; observed shortcuts and every other key pass through untouched.
@MainActor
final class HotKeys {
    static let shared = HotKeys()

    private struct Binding {
        let spec: HotKeySpec
        /// Registered shortcuts are swallowed; observed ones go on to their owner.
        let swallows: Bool
        let action: () -> Void
    }

    private var bindings: [Binding] = []
    private var tap: EventTap?

    /// Receives a key press while Settings records a shortcut.
    typealias Recorder = (_ keyCode: Int64, _ flags: CGEventFlags, _ isKeyDown: Bool) -> Void

    /// While set, key presses go here instead of starting anything, and are swallowed.
    /// The tap sees them before other apps' global shortcuts, so a shortcut another app
    /// also uses can still be recorded, and one macOS reserves can be recognized.
    var recorder: Recorder? {
        didSet { if recorder != nil { startTapIfNeeded() } }
    }

    func register(_ spec: HotKeySpec, action: @escaping () -> Void) {
        bindings.append(Binding(spec: spec, swallows: true, action: action))
        Log.app.info("registered hot key \(String(describing: spec), privacy: .public)")
        startTapIfNeeded()
    }

    /// Runs `action` when another app's or the system's shortcut is pressed, and lets the key
    /// through to its owner.
    func observe(_ spec: HotKeySpec, action: @escaping () -> Void) {
        bindings.append(Binding(spec: spec, swallows: false, action: action))
        Log.app.info("observing shortcut \(String(describing: spec), privacy: .public)")
        startTapIfNeeded()
    }

    func unregisterAll() {
        bindings.removeAll()
    }

    /// True when `press` is one of the registered shortcuts. Modes let these through their
    /// own key capture so the shortcut can also toggle a running mode off.
    func matches(_ press: KeyPress) -> Bool {
        recorder == nil
            && bindings.contains {
                $0.swallows && Self.matches($0.spec, keyCode: press.keyCode, flags: press.flags)
            }
    }

    fileprivate func handle(keyCode: Int64, flags: CGEventFlags) -> Bool {
        if let recorder {
            recorder(keyCode, flags, true)
            return true
        }
        let matched = bindings.filter { Self.matches($0.spec, keyCode: keyCode, flags: flags) }
        for binding in matched {
            Log.app.info("hot key \(String(describing: binding.spec), privacy: .public) pressed")
            // Later, not here: every key press on the system waits for this callback, and
            // starting a mode reads the frontmost app's whole accessibility tree.
            Task { binding.action() }
        }
        return matched.contains { $0.swallows }
    }

    fileprivate func modifiersChanged(_ flags: CGEventFlags) {
        recorder?(0, flags, false)
    }

    fileprivate func reenable() {
        tap?.reenable()
    }

    private func startTapIfNeeded() {
        guard tap == nil else { return }
        tap = EventTap(
            events: [.keyDown, .flagsChanged], callback: hotKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        if tap == nil {
            Log.app.error(
                "could not create the hot key event tap; is Accessibility permission granted?")
        }
    }

    private static let modifierMask: CGEventFlags = [
        .maskCommand, .maskAlternate, .maskControl, .maskShift,
    ]

    private static func matches(_ spec: HotKeySpec, keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard keyCode == Int64(spec.keyCode) else { return false }
        var expected: CGEventFlags = []
        if spec.modifiers.contains(.command) { expected.insert(.maskCommand) }
        if spec.modifiers.contains(.option) { expected.insert(.maskAlternate) }
        if spec.modifiers.contains(.control) { expected.insert(.maskControl) }
        if spec.modifiers.contains(.shift) { expected.insert(.maskShift) }
        return flags.intersection(modifierMask) == expected
    }
}

private func hotKeyCallback(
    _: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let hotKeys = Unmanaged<HotKeys>.fromOpaque(userInfo).takeUnretainedValue()
    // The tap's run loop source is on the main run loop, so the main actor is current.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { hotKeys.reenable() }
        return Unmanaged.passUnretained(event)
    }
    if type == .flagsChanged {
        let flags = event.flags
        MainActor.assumeIsolated { hotKeys.modifiersChanged(flags) }
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
        return Unmanaged.passUnretained(event)
    }
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    let swallow = MainActor.assumeIsolated { hotKeys.handle(keyCode: keyCode, flags: flags) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
