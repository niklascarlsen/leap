import AppKit
import LeapCore

/// Transparent, click-through windows covering every screen, above all other UI
/// (including Mission Control). Content is drawn by a `Drawing` in accessibility coordinates.
@MainActor
final class Overlay {
    /// Draws into a flipped view whose origin is the screen's top-left corner, given in
    /// accessibility coordinates as `origin`.
    typealias Drawing = (_ context: CGContext, _ origin: CGPoint) -> Void

    private var windows: [NSWindow] = []
    private var drawing: Drawing?

    /// The screen frames the windows were made for. Windows are kept between uses, since
    /// creating them costs frames that matter when labels follow Mission Control opening.
    private var screenFrames: [CGRect] = []

    func show(_ drawing: @escaping Drawing) {
        self.drawing = drawing
        let screens = NSScreen.screens.map(\.frame)
        if screens != screenFrames {
            for window in windows { window.orderOut(nil) }
            windows.removeAll()
            createWindows()
            screenFrames = screens
        }
        for window in windows {
            window.contentView?.needsDisplay = true
            window.orderFrontRegardless()
        }
    }

    func redraw() {
        for window in windows { window.contentView?.needsDisplay = true }
    }

    func hide() {
        drawing = nil
        // Clear the kept windows now, so showing them again cannot flash old labels.
        for window in windows {
            window.contentView?.display()
            window.orderOut(nil)
        }
    }

    private func createWindows() {
        let primaryHeight = ElementFinder.primaryScreenHeight
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.level = NSWindow.Level(
                rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
            window.collectionBehavior = [
                .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
            ]
            let origin = Geometry.accessibilityOrigin(
                ofScreenFrame: screen.frame, primaryScreenHeight: primaryHeight)
            window.contentView = OverlayView(origin: origin) { [weak self] context, origin in
                self?.drawing?(context, origin)
            }
            window.setFrame(screen.frame, display: false)
            windows.append(window)
        }
    }
}
