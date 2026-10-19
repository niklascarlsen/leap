import CoreGraphics

/// A `CGEventTap` that sees keyboard events before any app, on the main run loop, so its
/// callback runs on the main actor. The callback returns nil to swallow an event.
@MainActor
final class EventTap {
    private let tap: CFMachPort
    private let source: CFRunLoopSource

    /// Nil without Accessibility permission.
    init?(events: [CGEventType], callback: CGEventTapCallBack, userInfo: UnsafeMutableRawPointer) {
        let mask = events.reduce(CGEventMask(0)) { $0 | CGEventMask(1) << $1.rawValue }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask, callback: callback, userInfo: userInfo
            )
        else { return nil }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// macOS turns a tap off when its callback is too slow; this turns it back on.
    func reenable() {
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
}
