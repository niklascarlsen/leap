import AppKit

/// The app icon's jumping creature as a template image, which macOS tints to match the
/// menu bar: a filled body with the face cut out, like the system's own symbols. Drawn on
/// an 18-point grid, scaled up to fill the menu bar's height.
enum MenuBarIcon {
    static func image() -> NSImage {
        let side: CGFloat = 22
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let transform = NSAffineTransform()
            transform.scale(by: side / 18)
            transform.concat()
            NSColor.black.set()
            func line(from: NSPoint, to: NSPoint, width: CGFloat) {
                let path = NSBezierPath()
                path.move(to: from)
                path.line(to: to)
                path.lineWidth = width
                path.lineCapStyle = .round
                path.stroke()
            }
            line(from: NSPoint(x: 4.8, y: 6.2), to: NSPoint(x: 2.2, y: 2.9), width: 1.7)
            line(from: NSPoint(x: 13.2, y: 6.2), to: NSPoint(x: 15.8, y: 2.9), width: 1.7)
            line(from: NSPoint(x: 7.4, y: 12.4), to: NSPoint(x: 7.0, y: 15.4), width: 1.7)
            line(from: NSPoint(x: 10.6, y: 12.4), to: NSPoint(x: 11.0, y: 15.4), width: 1.7)
            NSBezierPath(ovalIn: NSRect(x: 3.6, y: 3.6, width: 10.8, height: 9.6)).fill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            for x in [7.3, 10.7] {
                NSBezierPath(ovalIn: NSRect(x: x - 0.85, y: 6.3, width: 1.7, height: 2.5)).fill()
            }
            let mouth = NSBezierPath()
            mouth.move(to: NSPoint(x: 7.6, y: 10.1))
            mouth.curve(
                to: NSPoint(x: 10.4, y: 10.1), controlPoint1: NSPoint(x: 8.3, y: 11.2),
                controlPoint2: NSPoint(x: 9.7, y: 11.2))
            mouth.lineWidth = 1.1
            mouth.lineCapStyle = .round
            mouth.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Leap"
        return image
    }
}
