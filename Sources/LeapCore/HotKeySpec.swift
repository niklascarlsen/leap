import Foundation

/// A global shortcut parsed from text such as `"ctrl+opt+cmd+l"` or `"f17"`.
public struct HotKeySpec: Equatable, Sendable {
    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    /// Virtual key code (`kVK_*` in Carbon's `Events.h`).
    public var keyCode: UInt32
    public var modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init?(_ text: String) {
        let parts = text.lowercased().split(separator: "+").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let key = parts.last, let code = Self.keyCodes[key] ?? Self.aliases[key] else {
            return nil
        }
        var modifiers: Modifiers = []
        for part in parts.dropLast() {
            switch part {
            case "cmd", "command": modifiers.insert(.command)
            case "opt", "option", "alt": modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            case "shift": modifiers.insert(.shift)
            default: return nil
            }
        }
        self.init(keyCode: code, modifiers: modifiers)
    }

    /// Leap's text form, e.g. `"shift+cmd+j"`, which `init?(_:)` reads back. Nil for keys
    /// without a name, which cannot be stored.
    public var text: String? {
        guard let name = Self.names[keyCode] else { return nil }
        let prefixes: [(Modifiers, String)] = [
            (.control, "ctrl"), (.option, "opt"), (.shift, "shift"), (.command, "cmd"),
        ]
        let held = prefixes.filter { modifiers.contains($0.0) }.map(\.1)
        return (held + [name]).joined(separator: "+")
    }

    /// How macOS menus show the shortcut, e.g. `"⇧⌘J"`. `character` gives the character the
    /// current keyboard layout puts on a key, so letters match the keycaps.
    public func displayString(character: (UInt32) -> String?) -> String {
        let symbols: [(Modifiers, String)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]
        let name = character(keyCode) ?? Self.names[keyCode]
        let key = Self.symbols[keyCode] ?? name?.uppercased() ?? "Key \(keyCode)"
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + key
    }

    public var isFunctionKey: Bool { functionKeyNumber != nil }

    /// 1 for F1 through 20 for F20.
    public var functionKeyNumber: Int? {
        Self.functionKeys.contains(keyCode)
            ? Self.names[keyCode].flatMap { Int($0.dropFirst()) } : nil
    }

    /// Why `self` cannot be a mode's shortcut, if it cannot. `otherMode` is the other mode's
    /// shortcut; `system` are the shortcuts macOS has enabled.
    public func problem(otherMode: HotKeySpec?, system: [HotKeySpec]) -> HotKeyProblem? {
        if text == nil { return .unsupportedKey }
        // Shift alone would take a capital letter from normal typing.
        if modifiers.subtracting(.shift).isEmpty && !isFunctionKey { return .needsModifier }
        // ⌘ with a single key is every app's own shortcuts: ⌘Q, ⌘W, ⌘C.
        if modifiers == .command && !isFunctionKey { return .usedByApps }
        if self == otherMode { return .usedByOtherMode }
        if system.contains(self) { return .usedByMacOS }
        return nil
    }

    /// A shortcut from `com.apple.symbolichotkeys`: parameters are (character, key code,
    /// modifier flags), the flags being `NSEvent.ModifierFlags` raw values.
    public init?(symbolicHotKeyParameters parameters: [Int]) {
        guard parameters.count == 3, parameters[1] >= 0, parameters[1] < 0xFFFF else { return nil }
        let flags = parameters[2]
        var modifiers: Modifiers = []
        if flags & (1 << 17) != 0 { modifiers.insert(.shift) }
        if flags & (1 << 18) != 0 { modifiers.insert(.control) }
        if flags & (1 << 19) != 0 { modifiers.insert(.option) }
        if flags & (1 << 20) != 0 { modifiers.insert(.command) }
        self.init(keyCode: UInt32(parameters[1]), modifiers: modifiers)
    }

    /// ANSI-position key codes by Leap's name for the key. Letters refer to the physical key
    /// position on an ANSI layout, which is what global hot keys are registered against.
    static let keyCodes: [String: UInt32] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
        "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
        "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
        "7": 0x1A, "8": 0x1C, "0": 0x1D, "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25,
        "j": 0x26, "k": 0x28, "n": 0x2D, "m": 0x2E,
        "equal": 0x18, "minus": 0x1B, "rightbracket": 0x1E, "leftbracket": 0x21, "quote": 0x27,
        "semicolon": 0x29, "backslash": 0x2A, "comma": 0x2B, "slash": 0x2C, "period": 0x2F,
        "grave": 0x32, "section": 0x0A,
        "space": 0x31, "tab": 0x30, "return": 0x24, "escape": 0x35, "delete": 0x33,
        "forwarddelete": 0x75, "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
        "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60, "f6": 0x61, "f7": 0x62,
        "f8": 0x64, "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F, "f13": 0x69, "f14": 0x6B,
        "f15": 0x71, "f16": 0x6A, "f17": 0x40, "f18": 0x4F, "f19": 0x50, "f20": 0x5A,
    ]

    static let aliases: [String: UInt32] = ["esc": 0x35, "enter": 0x24, "backspace": 0x33]

    static let names = Dictionary(uniqueKeysWithValues: keyCodes.map { ($1, $0) })

    /// F1-F20.
    static let functionKeys = Set(
        keyCodes.filter { $0.key.hasPrefix("f") && Int($0.key.dropFirst()) != nil }.values)

    /// Keys macOS menus show as a symbol or word rather than a character.
    static let symbols: [UInt32: String] = {
        var symbols: [UInt32: String] = [
            0x31: "Space", 0x30: "⇥", 0x24: "↩", 0x35: "⎋", 0x33: "⌫", 0x75: "⌦", 0x73: "↖",
            0x77: "↘", 0x74: "⇞", 0x79: "⇟", 0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        ]
        for code in functionKeys { symbols[code] = names[code]?.uppercased() }
        return symbols
    }()
}
