import LeapCore
import SwiftUI

/// The keys labels are made of, typed into a field.
struct LabelKeysRow: View {
    @AppStorage(Settings.Key.labelCharacters) private var stored = LabelGenerator.defaultAlphabet
    /// What the field shows: the stored keys, or what is being typed until it is cleaned.
    @State private var typed = ""

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField("Keys", text: $typed, prompt: Text(LabelGenerator.defaultAlphabet))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .multilineTextAlignment(.leading)
                    .frame(width: 134)
                    .visibleFocus()
                    // Rewriting the text after an edit, rather than within it, shows in the
                    // field while it is being edited, so it always shows the keys in use.
                    .onChange(of: typed) { _, text in
                        let cleaned = LabelGenerator.cleaned(text)
                        stored = cleaned
                        if cleaned != text { typed = cleaned }
                    }
                    .onChange(of: stored, initial: true) { _, keys in
                        if keys != typed { typed = keys }
                    }
                // Keeps the field's edge in line with the shortcut buttons above.
                Image(systemName: "xmark.circle.fill").hidden()
                Button(
                    "Restore the default keys", systemImage: "arrow.counterclockwise",
                    action: restoreDefault
                )
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Restore the default keys")
                .visibleFocus()
                .hiddenKeepingSpace(stored == LabelGenerator.defaultAlphabet)
            }
        } label: {
            Text("Keys")
            if stored.count < 2 {
                Text("Type at least two keys.").foregroundStyle(.red)
            } else {
                Text("The first keys get the shortest labels.")
            }
        }
    }

    private func restoreDefault() {
        stored = LabelGenerator.defaultAlphabet
    }
}
