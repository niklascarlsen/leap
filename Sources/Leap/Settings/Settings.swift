import AppKit
import LeapCore

/// User preferences, stored in `UserDefaults` (domain = bundle identifier).
///
/// Every value can also be set from a terminal, e.g.
/// `defaults write com.niklascarlsen.leap scrollBorderColor "#FF8800"`.
@MainActor
enum Settings {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let labelCharacters = "labelCharacters"
        static let labelFontSize = "labelFontSize"
        static let labelBackgroundColor = "labelBackgroundColor"
        static let labelTextColor = "labelTextColor"
        static let scrollBorderColor = "scrollBorderColor"
        static let scrollBorderWidth = "scrollBorderWidth"
        static let scrollSpeed = "scrollSpeed"
        static let scrollDashMultiplier = "scrollDashMultiplier"
        static let leapHotKey = "leapHotKey"
        static let scrollHotKey = "scrollHotKey"
        static let autoActivateInMissionControl = "autoActivateInMissionControl"
        static let hasLaunched = "hasLaunched"
    }

    enum Default {
        static let labelFontSize = 14.0
        static let labelBackgroundColor = "#FFD479"
        static let labelTextColor = "#000000"
        static let scrollBorderColor = "#FFD479"
        static let scrollBorderWidth = 3.0
        static let scrollSpeed = 1200.0
        static let scrollDashMultiplier = 3.0
        static let leapHotKey = "shift+cmd+space"
        static let scrollHotKey = "shift+cmd+j"
    }

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.labelCharacters: LabelGenerator.defaultAlphabet,
            Key.labelFontSize: Default.labelFontSize,
            Key.labelBackgroundColor: Default.labelBackgroundColor,
            Key.labelTextColor: Default.labelTextColor,
            Key.scrollBorderColor: Default.scrollBorderColor,
            Key.scrollBorderWidth: Default.scrollBorderWidth,
            Key.scrollSpeed: Default.scrollSpeed,
            Key.scrollDashMultiplier: Default.scrollDashMultiplier,
            Key.leapHotKey: Default.leapHotKey,
            Key.scrollHotKey: Default.scrollHotKey,
            Key.autoActivateInMissionControl: true,
        ])
    }

    /// Start leap mode automatically whenever Mission Control opens.
    static var autoActivateInMissionControl: Bool {
        get { defaults.bool(forKey: Key.autoActivateInMissionControl) }
        set { defaults.set(newValue, forKey: Key.autoActivateInMissionControl) }
    }

    static var labelAlphabet: [Character] {
        LabelGenerator.alphabet(from: defaults.string(forKey: Key.labelCharacters) ?? "")
    }

    static var labelFontSize: CGFloat { CGFloat(defaults.double(forKey: Key.labelFontSize)) }
    static var labelBackgroundColor: NSColor { color(Key.labelBackgroundColor) }
    static var labelTextColor: NSColor { color(Key.labelTextColor) }
    static var scrollBorderWidth: CGFloat {
        CGFloat(defaults.double(forKey: Key.scrollBorderWidth))
    }
    /// Points per second.
    static var scrollSpeed: Double { defaults.double(forKey: Key.scrollSpeed) }
    static var scrollDashMultiplier: Double { defaults.double(forKey: Key.scrollDashMultiplier) }

    static var scrollBorderColor: NSColor { color(Key.scrollBorderColor) }

    static var leapHotKey: HotKeySpec? { hotKey(Key.leapHotKey) }
    static var scrollHotKey: HotKeySpec? { hotKey(Key.scrollHotKey) }

    /// A mode's shortcut, nil when it has none. An empty string turns a shortcut off.
    static func hotKey(_ key: String) -> HotKeySpec? {
        HotKeySpec(defaults.string(forKey: key) ?? "")
    }

    static func setHotKey(_ spec: HotKeySpec?, for key: String) {
        defaults.set(spec?.text ?? "", forKey: key)
    }

    static func resetHotKey(_ key: String) {
        defaults.removeObject(forKey: key)
    }

    /// True on the very first launch, then never again.
    static func isFirstLaunch() -> Bool {
        guard !defaults.bool(forKey: Key.hasLaunched) else { return false }
        defaults.set(true, forKey: Key.hasLaunched)
        return true
    }

    /// Calls `handler` whenever one of `keys` changes, also from `defaults write`. The
    /// returned object keeps the observation alive.
    static func observe(_ keys: [String], _ handler: @escaping @MainActor () -> Void) -> AnyObject {
        DefaultsObserver(defaults: defaults, keys: keys, handler: handler)
    }

    private static func color(_ key: String) -> NSColor {
        let registered = defaults.volatileDomain(forName: UserDefaults.registrationDomain)
        let parsed =
            HexColor(defaults.string(forKey: key) ?? "")
            ?? HexColor(registered[key] as? String ?? "")
            ?? HexColor(red: 1, green: 0, blue: 1)
        return NSColor(
            srgbRed: parsed.red, green: parsed.green, blue: parsed.blue, alpha: parsed.alpha)
    }

    static func hex(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        return HexColor(
            red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent,
            alpha: srgb.alphaComponent
        ).hexString
    }
}
