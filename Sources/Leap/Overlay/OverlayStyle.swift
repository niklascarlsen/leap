import AppKit

/// How labels and the scroll border look, shared by the overlays and the Settings preview.
@MainActor
enum OverlayStyle {
    /// The label's outer box, vertically centered on `point`, with its left edge at `point`
    /// or, when `centered`, horizontally centered on it. Coordinates are those of `point`.
    static func labelRect(_ text: String, at point: CGPoint, centered: Bool = false) -> CGRect {
        let textSize = attributed(text, typed: 0).size()
        let metrics = labelMetrics
        let width = textSize.width + metrics.padding.width * 2
        return CGRect(
            x: centered ? point.x - width / 2 : point.x,
            y: point.y - textSize.height / 2 - metrics.padding.height,
            width: width, height: textSize.height + metrics.padding.height * 2
        ).integral
    }

    /// Draws a pill-shaped label filling `rect` (from `labelRect`). The first `typed`
    /// characters are drawn faded to show progress.
    static func drawLabel(_ text: String, typed: Int, in rect: CGRect, context: CGContext) {
        let metrics = labelMetrics
        let path = CGPath(
            roundedRect: rect, cornerWidth: metrics.radius, cornerHeight: metrics.radius,
            transform: nil)

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 1), blur: 3,
            color: NSColor.black.withAlphaComponent(0.35).cgColor)
        context.addPath(path)
        context.setFillColor(Settings.labelBackgroundColor.cgColor)
        context.fillPath()
        context.restoreGState()

        context.addPath(path)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1)
        context.strokePath()

        NSGraphicsContext.saveGraphicsState()
        attributed(text, typed: typed).draw(
            at: CGPoint(x: rect.minX + metrics.padding.width, y: rect.minY + metrics.padding.height)
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Convenience for one-off labels (scroll area numbers, the settings preview).
    static func drawLabel(
        _ text: String, typed: Int, at point: CGPoint, centered: Bool = false, in context: CGContext
    ) {
        drawLabel(
            text, typed: typed, in: labelRect(text, at: point, centered: centered), context: context
        )
    }

    /// Proportions scale with the font so large labels keep the same shape.
    private static var labelMetrics: (padding: CGSize, radius: CGFloat) {
        let fontSize = Settings.labelFontSize
        return (
            CGSize(width: (fontSize * 0.35).rounded(), height: max(1, (fontSize * 0.1).rounded())),
            (fontSize * 0.3).rounded()
        )
    }

    private static func attributed(_ text: String, typed: Int) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: Settings.labelFontSize, weight: .bold)
        let textColor = Settings.labelTextColor
        let string = NSMutableAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: textColor])
        if typed > 0 {
            string.addAttribute(
                .foregroundColor, value: textColor.withAlphaComponent(0.35),
                range: NSRange(location: 0, length: min(typed, text.utf16.count)))
        }
        return string
    }

    /// Draws the border that marks the selected scroll area. `rect` is the area itself;
    /// the stroke stays inside it.
    static func drawScrollBorder(around rect: CGRect, in context: CGContext) {
        let width = Settings.scrollBorderWidth
        let inset = rect.insetBy(dx: width / 2, dy: width / 2)
        context.addPath(
            CGPath(roundedRect: inset, cornerWidth: 10, cornerHeight: 10, transform: nil))
        context.setStrokeColor(Settings.scrollBorderColor.cgColor)
        context.setLineWidth(width)
        context.strokePath()
    }
}
