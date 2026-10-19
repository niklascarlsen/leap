// Posts one key press with real modifier key events (Carbon-style shortcuts ignore bare flags):
// key <keycode> [ctrl] [opt] [cmd] [shift] [fn] [hold=<ms>]; fn is the Globe key
import CoreGraphics
import Foundation

let args = CommandLine.arguments.dropFirst()
let code = CGKeyCode(args.first!)!
let modifiers: [(String, CGKeyCode, CGEventFlags)] = [
    ("ctrl", 59, .maskControl), ("opt", 58, .maskAlternate), ("cmd", 55, .maskCommand),
    ("shift", 56, .maskShift),
    ("fn", 63, .maskSecondaryFn),
]
let active = modifiers.filter { args.contains($0.0) }
var flags: CGEventFlags = []
func post(_ key: CGKeyCode, _ down: Bool) {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)!
    e.flags = flags
    e.post(tap: .cghidEventTap)
    usleep(15_000)
}
for (_, key, flag) in active {
    flags.insert(flag)
    post(key, true)
}
post(code, true)
if let hold = args.first(where: { $0.hasPrefix("hold=") }), let ms = UInt32(hold.dropFirst(5)) {
    usleep(ms * 1000)
}
post(code, false)
for (_, key, flag) in active.reversed() {
    flags.remove(flag)
    post(key, false)
}
