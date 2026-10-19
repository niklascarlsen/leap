// move <x> <y>: posts real mouse-moved events (warping alone does not, so auto-hide UI ignores it)
import CoreGraphics
import Foundation

let target = CGPoint(x: Double(CommandLine.arguments[1])!, y: Double(CommandLine.arguments[2])!)
let start = CGEvent(source: nil)!.location
for i in 1...10 {
    let t = Double(i) / 10
    let p = CGPoint(x: start.x + (target.x - start.x) * t, y: start.y + (target.y - start.y) * t)
    CGEvent(
        mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!
        .post(
            tap: .cghidEventTap)
    usleep(20_000)
}
