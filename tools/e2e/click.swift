// Posts one left click at global top-left-origin coordinates: click <x> <y>
import CoreGraphics

let x = Double(CommandLine.arguments[1])!
let y = Double(CommandLine.arguments[2])!
for t in [CGEventType.leftMouseDown, .leftMouseUp] {
    CGEvent(
        mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGPoint(x: x, y: y),
        mouseButton: .left)!.post(
            tap: .cghidEventTap)
}
