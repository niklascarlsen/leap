import LeapCore
import SwiftUI

/// The Appearance tab: the labels' size and colors, and the scroll border.
struct AppearanceSettings: View {
    @AppStorage(Settings.Key.labelFontSize) private var labelFontSize = Settings.Default
        .labelFontSize
    @AppStorage(Settings.Key.labelBackgroundColor) private var labelBackground = Settings.Default
        .labelBackgroundColor
    @AppStorage(Settings.Key.labelTextColor) private var labelText = Settings.Default.labelTextColor
    @AppStorage(Settings.Key.scrollBorderColor) private var borderColor = Settings.Default
        .scrollBorderColor
    @AppStorage(Settings.Key.scrollBorderWidth) private var borderWidth = Settings.Default
        .scrollBorderWidth

    var body: some View {
        Form {
            Section("Labels") {
                LabeledContent("Size") {
                    HStack {
                        Slider(value: whole($labelFontSize), in: 10...36).visibleFocus()
                        Text("\(Int(labelFontSize)) pt").monospacedDigit().frame(
                            width: 44, alignment: .trailing)
                    }
                }
                ColorPicker(
                    "Background", selection: hexColor($labelBackground), supportsOpacity: true
                )
                .visibleFocus(row: true)
                ColorPicker("Text", selection: hexColor($labelText), supportsOpacity: true)
                    .visibleFocus(row: true)
            }
            Section("Scroll mode") {
                ColorPicker("Border", selection: hexColor($borderColor), supportsOpacity: true)
                    .visibleFocus(row: true)
                LabeledContent("Border width") {
                    HStack {
                        Slider(value: whole($borderWidth), in: 1...12).visibleFocus()
                        Text("\(Int(borderWidth)) pt").monospacedDigit().frame(
                            width: 44, alignment: .trailing)
                    }
                }
            }
            Section("Preview") {
                // The token changes with every setting so the preview redraws.
                SettingsPreview(
                    token:
                        "\(labelFontSize)\(labelBackground)\(labelText)\(borderColor)\(borderWidth)"
                )
                .frame(height: 140)
            }
            HStack {
                Spacer()
                Button("Restore Defaults", action: restoreDefaults).visibleFocus()
            }
        }
        .formStyle(.grouped)
        .glassWindowBackground()
    }

    private func restoreDefaults() {
        labelFontSize = Settings.Default.labelFontSize
        labelBackground = Settings.Default.labelBackgroundColor
        labelText = Settings.Default.labelTextColor
        borderColor = Settings.Default.scrollBorderColor
        borderWidth = Settings.Default.scrollBorderWidth
    }

    /// Rounds to whole points. A stepped `Slider` would draw a tick mark for every step.
    private func whole(_ value: Binding<Double>) -> Binding<Double> {
        Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0.rounded() })
    }

    /// Bridges a stored `#RRGGBBAA` string to a SwiftUI color.
    private func hexColor(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: {
                let parsed = HexColor(hex.wrappedValue) ?? HexColor(red: 1, green: 0, blue: 1)
                return Color(
                    .sRGB, red: parsed.red, green: parsed.green, blue: parsed.blue,
                    opacity: parsed.alpha)
            },
            set: { hex.wrappedValue = Settings.hex(NSColor($0)) }
        )
    }
}
