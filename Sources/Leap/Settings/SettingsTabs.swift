import AppKit

/// The system marks the selected tab with accent-colored text, which is hard to read on
/// glass, so the selected tab is marked as a prominent item instead.
final class SettingsTabs: NSTabViewController {
    override func toolbarSelectableItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        markSelectedTab()
    }

    override func tabView(_ tabView: NSTabView, didSelect item: NSTabViewItem?) {
        super.tabView(tabView, didSelect: item)
        markSelectedTab()
    }

    private func markSelectedTab() {
        guard let toolbar = view.window?.toolbar else { return }
        let selected = tabViewItems[selectedTabViewItemIndex].label
        for item in toolbar.items {
            item.style = item.label == selected ? .prominent : .plain
        }
    }
}
