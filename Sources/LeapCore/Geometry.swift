import CoreGraphics

/// Rectangle math: conversions between the two global coordinate systems on macOS, and areas.
///
/// Accessibility and Quartz events use a top-left origin at the primary display.
/// AppKit (`NSScreen`, `NSWindow`) uses a bottom-left origin at the primary display.
public enum Geometry {
    /// The top-left corner of an AppKit screen frame, expressed in accessibility coordinates.
    public static func accessibilityOrigin(
        ofScreenFrame frame: CGRect, primaryScreenHeight: CGFloat
    ) -> CGPoint {
        CGPoint(x: frame.minX, y: primaryScreenHeight - frame.maxY)
    }

    /// The screen frame in accessibility coordinates.
    public static func accessibilityFrame(ofScreenFrame frame: CGRect, primaryScreenHeight: CGFloat)
        -> CGRect
    {
        CGRect(
            origin: accessibilityOrigin(
                ofScreenFrame: frame, primaryScreenHeight: primaryScreenHeight),
            size: frame.size)
    }

    public static func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    /// Area of the union of possibly overlapping rects.
    public static func unionArea(_ rects: [CGRect]) -> CGFloat {
        let xs = Set(rects.flatMap { [$0.minX, $0.maxX] }).sorted()
        var total: CGFloat = 0
        for (left, right) in zip(xs, xs.dropFirst()) {
            let spans = rects.filter { $0.minX <= left && $0.maxX >= right }
                .map { ($0.minY, $0.maxY) }.sorted { $0.0 < $1.0 }
            var covered: CGFloat = 0
            var end = -CGFloat.infinity
            for (top, bottom) in spans where bottom > end {
                covered += bottom - max(top, end)
                end = bottom
            }
            total += covered * (right - left)
        }
        return total
    }
}
