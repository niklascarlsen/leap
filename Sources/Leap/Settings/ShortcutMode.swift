/// A mode whose shortcut can be recorded in Settings.
enum ShortcutMode {
    case leap, scroll

    /// Where the shortcut is stored.
    @MainActor var key: String {
        self == .leap ? Settings.Key.leapHotKey : Settings.Key.scrollHotKey
    }
    var other: ShortcutMode { self == .leap ? .scroll : .leap }
    var name: String { self == .leap ? "leap mode" : "scroll mode" }
}
