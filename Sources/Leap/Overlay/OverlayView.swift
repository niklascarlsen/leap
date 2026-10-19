import AppKit

/// Draws an overlay window's content with its `Overlay.Drawing`.
final class OverlayView: NSView {
    private let origin: CGPoint
    private let draw: Overlay.Drawing

    init(origin: CGPoint, draw: @escaping Overlay.Drawing) {
        self.origin = origin
        self.draw = draw
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        draw(context, origin)
    }
}
