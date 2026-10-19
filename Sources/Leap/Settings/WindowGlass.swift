import SwiftUI

/// The system's Liquid Glass, so the window follows the Clear or Tinted choice in System
/// Settings like the Dock and Control Center do.
struct WindowGlass: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSGlassEffectView { NSGlassEffectView() }

    func updateNSView(_: NSGlassEffectView, context _: Context) {}
}
