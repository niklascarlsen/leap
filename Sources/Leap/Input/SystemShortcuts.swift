import Foundation
import LeapCore

/// The shortcuts in System Settings > Keyboard > Keyboard Shortcuts.
enum SystemShortcuts {
    /// Every enabled shortcut, by its symbolic hot key number. macOS only stores the ones it
    /// has written once, so a shortcut never touched since setup can be missing.
    static var enabled: [String: HotKeySpec] {
        let defaults = UserDefaults(suiteName: "com.apple.symbolichotkeys")
        let hotKeys = defaults?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        return hotKeys.compactMapValues { entry in
            guard let entry = entry as? [String: Any], (entry["enabled"] as? Bool) ?? true,
                let value = entry["value"] as? [String: Any],
                let parameters = value["parameters"] as? [Int]
            else { return nil }
            return HotKeySpec(symbolicHotKeyParameters: parameters)
        }
    }

    /// 32 is "Mission Control".
    static var missionControl: HotKeySpec? { enabled["32"] }
}
