import CoreGraphics

/// Synthetic mouse input. Points are in global top-left-origin (Quartz) coordinates.
enum Mouse {
    static var location: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    static func click(at point: CGPoint, right: Bool = false, restoreCursor: Bool = true) {
        let original = location
        let (down, up, button): (CGEventType, CGEventType, CGMouseButton) =
            right ? (.rightMouseDown, .rightMouseUp, .right) : (.leftMouseDown, .leftMouseUp, .left)
        post(.mouseMoved, at: point, button: button)
        post(down, at: point, button: button)
        post(up, at: point, button: button)
        if restoreCursor { CGWarpMouseCursorPosition(original) }
    }

    static func move(to point: CGPoint) {
        post(.mouseMoved, at: point, button: .left)
    }

    /// Posts one pixel-precise scroll event. Positive `dy` scrolls content up (towards the top).
    static func scroll(dx: Int32, dy: Int32) {
        guard dx != 0 || dy != 0,
            let event = CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx,
                wheel3: 0)
        else { return }
        event.post(tap: .cghidEventTap)
    }

    private static func post(_ type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        CGEvent(
            mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)?
            .post(tap: .cghidEventTap)
    }
}
