import SwiftUI

/// A focus ring in the label color, `outset` beyond the view. See `View.visibleFocus(row:)`.
struct VisibleFocus: ViewModifier {
    let outset: CGSize
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .focusEffectDisabled()
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(nsColor: Settings.labelBackgroundColor), lineWidth: 2.5)
                    .padding(.horizontal, -outset.width)
                    .padding(.vertical, -outset.height)
                    .opacity(focused ? 1 : 0)
                    .allowsHitTesting(false)
            }
    }
}
