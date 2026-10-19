import SwiftUI

/// The General tab: opening at login, the shortcuts, and the keys labels are made of.
struct GeneralSettings: View {
    @State private var recorder = ShortcutRecorder()
    @AppStorage(Settings.Key.leapHotKey) private var leapHotKey = Settings.Default.leapHotKey
    @AppStorage(Settings.Key.scrollHotKey) private var scrollHotKey = Settings.Default.scrollHotKey
    @AppStorage(Settings.Key.autoActivateInMissionControl) private
        var autoActivateInMissionControl = true

    var body: some View {
        Form {
            Section {
                LaunchAtLoginRows()
            }
            Section("Shortcuts") {
                ShortcutRow(
                    title: "Leap", mode: .leap, stored: leapHotKey,
                    defaultValue: Settings.Default.leapHotKey,
                    recorder: recorder
                )
                ShortcutRow(
                    title: "Scroll", mode: .scroll, stored: scrollHotKey,
                    defaultValue: Settings.Default.scrollHotKey,
                    recorder: recorder
                )
                Toggle(isOn: $autoActivateInMissionControl) {
                    Text("Leap in Mission Control")
                    Text("Starts when Mission Control opens.")
                }
                .visibleFocus(row: true)
            }
            Section("Labels") {
                LabelKeysRow()
            }
        }
        .formStyle(.grouped)
        .onDisappear { recorder.stop() }
        .glassWindowBackground()
    }
}
