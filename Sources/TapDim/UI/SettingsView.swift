import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Brightness") {
                HStack {
                    Text("Target brightness")
                    Spacer()
                    Text("\(Int(settings.targetBrightness * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $settings.targetBrightness,
                    in: Constants.targetBrightnessMin...Constants.targetBrightnessMax,
                    step: 0.01
                )
            }

            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Toggle dim:", name: .toggleDim)
            }

            Section("General") {
                Toggle("Enable TapDim", isOn: $settings.isEnabled)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        LoginItemManager.shared.setEnabled(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 320)
    }
}
