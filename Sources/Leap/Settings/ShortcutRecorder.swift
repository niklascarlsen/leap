import AppKit
import LeapCore

/// Records a shortcut from the keys typed while Settings is the key window.
@MainActor @Observable
final class ShortcutRecorder {
    /// Why the last shortcut typed for `mode` was turned down.
    struct Problem {
        let mode: ShortcutMode
        let message: String
    }

    private(set) var recording: ShortcutMode?
    /// The modifiers held so far, shown while recording.
    private(set) var held: HotKeySpec.Modifiers = []
    private(set) var problem: Problem?
    @ObservationIgnored private var resignObserver: NSObjectProtocol?

    var pending: String {
        let symbols: [(HotKeySpec.Modifiers, String)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]
        let text = symbols.filter { held.contains($0.0) }.map(\.1).joined()
        return text.isEmpty ? "Type Shortcut" : text
    }

    func toggle(_ mode: ShortcutMode) {
        let wasRecording = recording == mode
        stop()
        if !wasRecording { start(mode) }
    }

    private func start(_ mode: ShortcutMode) {
        Log.app.debug(
            "recording a shortcut for \(mode.name, privacy: .public), key window: \(NSApp.keyWindow?.title ?? "none", privacy: .public)"
        )
        recording = mode
        problem = nil
        // The event tap sees keys before other apps' global shortcuts, so a shortcut another
        // app also uses can still be recorded, and one macOS reserves can be recognized.
        HotKeys.shared.recorder = { [weak self] keyCode, flags, isKeyDown in
            self?.handle(
                keyCode: UInt16(keyCode), isKey: isKeyDown, modifiers: Self.modifiers(of: flags))
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: NSApp.keyWindow, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    func stop() {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        recording = nil
        held = []
        HotKeys.shared.recorder = nil
    }

    private func handle(keyCode: UInt16, isKey: Bool, modifiers: HotKeySpec.Modifiers) {
        guard let mode = recording else { return }
        Log.app.debug(
            "recording \(mode.name, privacy: .public): \(isKey ? "key \(keyCode)" : "flags", privacy: .public) \(modifiers.rawValue)"
        )
        guard isKey else {
            held = modifiers
            return
        }
        if keyCode == KeyPress.escape && modifiers.isEmpty {
            stop()
            return
        }
        let spec = HotKeySpec(keyCode: UInt32(keyCode), modifiers: modifiers)
        let system = Array(SystemShortcuts.enabled.values)
        if let found = spec.problem(otherMode: Settings.hotKey(mode.other.key), system: system) {
            problem = Problem(mode: mode, message: Self.message(for: found, other: mode.other))
            NSSound.beep()
        } else {
            problem = nil
            Settings.setHotKey(spec, for: mode.key)
            stop()
        }
    }

    private static func modifiers(of flags: CGEventFlags) -> HotKeySpec.Modifiers {
        var modifiers: HotKeySpec.Modifiers = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        return modifiers
    }

    private static func message(for problem: HotKeyProblem, other: ShortcutMode) -> String {
        switch problem {
        case .unsupportedKey: "Leap cannot use that key."
        case .needsModifier: "Add ⌃, ⌥ or ⌘ so typing keeps working, or use an F key."
        case .usedByApps: "Apps use ⌘ with one key. Add ⌃, ⌥ or ⇧."
        case .usedByOtherMode: "Already the shortcut for \(other.name)."
        case .usedByMacOS: "macOS already uses this shortcut."
        }
    }
}
