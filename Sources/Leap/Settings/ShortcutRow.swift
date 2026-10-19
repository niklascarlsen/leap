import LeapCore
import SwiftUI

/// One mode's shortcut: a button that records a new one, and buttons that remove it or
/// restore the default.
struct ShortcutRow: View {
    let title: String
    let mode: ShortcutMode
    /// The stored text; only read so the row redraws when it changes.
    let stored: String
    let defaultValue: String
    let recorder: ShortcutRecorder

    var body: some View {
        let spec = HotKeySpec(stored)
        let recording = recorder.recording == mode
        LabeledContent {
            HStack(spacing: 6) {
                let title =
                    recording ? recorder.pending : spec.map(KeyboardLayout.display) ?? "None"
                let button = Button(action: toggleRecording) {
                    Text(title)
                        .foregroundStyle(spec == nil && !recording ? .secondary : .primary)
                        .frame(minWidth: 110)
                }
                .help(
                    recording
                        ? "Type a shortcut, or press Escape to cancel"
                        : "Click to record a new shortcut")
                Group {
                    if recording {
                        button.buttonStyle(.borderedProminent)
                    } else {
                        button.buttonStyle(.bordered)
                    }
                }
                .visibleFocus()
                Button("Remove the shortcut", systemImage: "xmark.circle.fill", action: remove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove the shortcut")
                    .visibleFocus()
                    .hiddenKeepingSpace(spec == nil)
                Button(
                    "Restore the default shortcut", systemImage: "arrow.counterclockwise",
                    action: restoreDefault
                )
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Restore the default shortcut")
                .visibleFocus()
                .hiddenKeepingSpace(stored == defaultValue)
            }
        } label: {
            Text(title)
            if let problem = recorder.problem, problem.mode == mode {
                Text(problem.message).foregroundStyle(.red)
            }
        }
    }

    private func toggleRecording() {
        recorder.toggle(mode)
    }

    private func remove() {
        recorder.stop()
        Settings.setHotKey(nil, for: mode.key)
    }

    private func restoreDefault() {
        recorder.stop()
        Settings.resetHotKey(mode.key)
    }
}
