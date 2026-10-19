import SwiftUI

/// Modifiers shared by the Settings tabs.
extension View {
    /// A tab's fixed width and fitted height, over the window's Liquid Glass.
    func glassWindowBackground() -> some View {
        scrollContentBackground(.hidden)
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
            .background { WindowGlass().ignoresSafeArea() }
    }

    /// Draws the keyboard focus in the label color. The system's ring is a thin accent line
    /// that all but disappears on glass.
    /// A `row` is a whole form row (a toggle or color picker with its title), framed out to
    /// the row's edges so the ring clears the title.
    func visibleFocus(row: Bool = false) -> some View {
        modifier(
            VisibleFocus(outset: row ? CGSize(width: 8, height: 5) : CGSize(width: 3, height: 3)))
    }

    /// Hides an inapplicable button but keeps its place, so the row does not shift.
    func hiddenKeepingSpace(_ hidden: Bool) -> some View {
        opacity(hidden ? 0 : 1).disabled(hidden).accessibilityHidden(hidden)
    }
}
