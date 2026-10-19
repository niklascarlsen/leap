import SwiftUI

/// The "Open at login" switch, and a way to System Settings while macOS waits for the
/// user to allow it there.
struct LaunchAtLoginRows: View {
    @State private var isEnabled = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.needsApproval

    var body: some View {
        // The system owns this setting, so the switch asks it rather than storing a value.
        Toggle("Open at login", isOn: Binding(get: { isEnabled }, set: setEnabled))
            .visibleFocus(row: true)
            // It may have changed in System Settings meanwhile.
            .onReceive(
                NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            ) { _ in
                refresh()
            }
        if needsApproval {
            LabeledContent {
                Button("Open Login Items", action: LaunchAtLogin.openSystemSettings).visibleFocus()
            } label: {
                Text("Allow Leap in System Settings")
                Text("macOS opens Leap at login once it is allowed there.")
            }
        }
    }

    private func setEnabled(_ enabled: Bool) {
        LaunchAtLogin.set(enabled)
        refresh()
    }

    private func refresh() {
        isEnabled = LaunchAtLogin.isEnabled
        needsApproval = LaunchAtLogin.needsApproval
    }
}
