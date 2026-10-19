import AppKit
import Carbon.HIToolbox
import LeapCore

/// Names keys the way the current keyboard layout labels them, so a shortcut on the key
/// right of L shows as "Ö" on a Swedish keyboard and ";" on a US one.
@MainActor
enum KeyboardLayout {
    static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layout = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layout.withUnsafeBytes { bytes -> OSStatus in
            guard let base = bytes.baseAddress else { return OSStatus(paramErr) }
            return UCKeyTranslate(
                base.assumingMemoryBound(to: UCKeyboardLayout.self), UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, characters.count, &length, &characters
            )
        }
        guard status == noErr else { return nil }
        let text = String(utf16CodeUnits: characters, count: length)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return text.isEmpty ? nil : text
    }

    static func display(_ spec: HotKeySpec) -> String {
        spec.displayString(character: character(for:))
    }

    /// The key equivalent that makes a menu item show `spec`, for keys a menu can show.
    static func menuKeyEquivalent(for spec: HotKeySpec) -> (
        key: String, modifiers: NSEvent.ModifierFlags
    )? {
        let special: [UInt32: Int] = [
            0x31: 0x20, 0x30: 0x09, 0x24: 0x0D, 0x35: 0x1B, 0x33: 0x08, 0x75: NSDeleteFunctionKey,
            0x73: NSHomeFunctionKey, 0x77: NSEndFunctionKey, 0x74: NSPageUpFunctionKey,
            0x79: NSPageDownFunctionKey,
            0x7B: NSLeftArrowFunctionKey, 0x7C: NSRightArrowFunctionKey,
            0x7D: NSDownArrowFunctionKey,
            0x7E: NSUpArrowFunctionKey,
        ]
        let key: String
        if let number = spec.functionKeyNumber,
            let scalar = UnicodeScalar(NSF1FunctionKey + number - 1)
        {
            key = String(Character(scalar))
        } else if let code = special[spec.keyCode], let scalar = UnicodeScalar(code) {
            key = String(Character(scalar))
        } else if let character = character(for: spec.keyCode) {
            key = character.lowercased()
        } else {
            return nil
        }
        var modifiers: NSEvent.ModifierFlags = []
        if spec.modifiers.contains(.control) { modifiers.insert(.control) }
        if spec.modifiers.contains(.option) { modifiers.insert(.option) }
        if spec.modifiers.contains(.shift) { modifiers.insert(.shift) }
        if spec.modifiers.contains(.command) { modifiers.insert(.command) }
        return (key, modifiers)
    }
}
