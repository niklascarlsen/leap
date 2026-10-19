import SwiftUI

/// Renders labels and a scroll border with the exact drawing code the overlays use.
struct SettingsPreview: NSViewRepresentable {
    /// Changes whenever a setting does, which makes SwiftUI call `updateNSView`.
    let token: String

    func makeNSView(context _: Context) -> PreviewView { PreviewView() }

    func updateNSView(_ view: PreviewView, context _: Context) {
        view.needsDisplay = true
    }

    final class PreviewView: NSView {
        override var isFlipped: Bool { true }

        override func draw(_: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            let area = bounds.insetBy(dx: 8, dy: 8)
            MainActor.assumeIsolated {
                OverlayStyle.drawScrollBorder(around: area, in: context)
                let row = area.midY
                OverlayStyle.drawLabel(
                    "S", typed: 0, at: CGPoint(x: area.minX + 24, y: row), in: context)
                OverlayStyle.drawLabel(
                    "DF", typed: 0, at: CGPoint(x: area.midX - 40, y: row), in: context)
                OverlayStyle.drawLabel(
                    "JK", typed: 1, at: CGPoint(x: area.midX + 60, y: row), in: context)
            }
        }
    }
}
