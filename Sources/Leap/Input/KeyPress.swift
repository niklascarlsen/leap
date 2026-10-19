import CoreGraphics

/// A key event delivered while a mode is active.
struct KeyPress: Sendable {
    enum Kind { case down, up }

    let kind: Kind
    let keyCode: Int64
    /// Layout-aware characters for the key, without modifiers applied except Shift.
    let characters: String
    let flags: CGEventFlags
    let isRepeat: Bool

    var shift: Bool { flags.contains(.maskShift) }
    var command: Bool { flags.contains(.maskCommand) }

    static let escape: Int64 = 53
    static let delete: Int64 = 51
    static let tab: Int64 = 48

    init?(type: CGEventType, event: CGEvent) {
        guard type == .keyDown || type == .keyUp else { return nil }
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        kind = type == .keyDown ? .down : .up
        keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        characters = String(utf16CodeUnits: buffer, count: length)
        flags = event.flags
        isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }
}
