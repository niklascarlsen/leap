import CoreGraphics
import Testing

@testable import LeapCore

struct GeometryTests {
    @Test func primaryScreenTopLeftIsZero() {
        let frame = CGRect(x: 0, y: 0, width: 5120, height: 1440)
        #expect(
            Geometry.accessibilityOrigin(ofScreenFrame: frame, primaryScreenHeight: 1440) == .zero)
    }

    @Test func secondaryScreenAbovePrimary() {
        // AppKit: a 1920x1080 screen placed directly above a 1440 high primary.
        let frame = CGRect(x: 100, y: 1440, width: 1920, height: 1080)
        let origin = Geometry.accessibilityOrigin(ofScreenFrame: frame, primaryScreenHeight: 1440)
        #expect(origin == CGPoint(x: 100, y: -1080))
    }

    @Test func measuresOverlappingRectsOnce() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 5, y: 5, width: 10, height: 10)
        #expect(Geometry.unionArea([a, b]) == 175)
        #expect(Geometry.unionArea([a, a]) == 100)
    }
}
