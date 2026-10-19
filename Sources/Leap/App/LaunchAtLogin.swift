import ServiceManagement

/// Opening Leap at login, through the system's login items. The system is the only record
/// of it, so the user can also change it in System Settings > General > Login Items.
@MainActor
enum LaunchAtLogin {
    /// Also true while waiting for the user's approval: Leap asked, the user still has to allow it.
    static var isEnabled: Bool {
        [.enabled, .requiresApproval].contains(SMAppService.mainApp.status)
    }

    /// True when the user has to allow Leap in System Settings before it opens at login.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.app.info(
                "open at login: \(enabled), status \(SMAppService.mainApp.status.rawValue)")
        } catch {
            Log.app.error(
                "could not \(enabled ? "enable" : "disable", privacy: .public) open at login: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
