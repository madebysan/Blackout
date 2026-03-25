import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    private let tapDetector = TapDetector.shared

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

            Section("Tap Detection") {
                if tapDetector.isAvailable {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Accelerometer active")
                            .foregroundStyle(.secondary)
                    }
                } else if tapDetector.permissionNeeded {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("Input Monitoring required")
                            Text("System Settings > Privacy > Input Monitoring")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("No accelerometer found")
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Taps to trigger", selection: $settings.tapsRequired) {
                    Text("1 tap").tag(1)
                    Text("2 taps").tag(2)
                    Text("3 taps").tag(3)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Sensitivity")
                    Spacer()
                    Text(String(format: "%.2fg", settings.tapSensitivity))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $settings.tapSensitivity,
                    in: Constants.tapSensitivityMin...Constants.tapSensitivityMax,
                    step: 0.01
                )

                HStack {
                    Text("Tap window")
                    Spacer()
                    Text("\(Int(settings.tapWindow * 1000))ms")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $settings.tapWindow,
                    in: Constants.tapWindowMin...Constants.tapWindowMax,
                    step: 0.05
                )

                HStack {
                    Text("Cooldown")
                    Spacer()
                    Text(String(format: "%.1fs", settings.cooldown))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $settings.cooldown,
                    in: Constants.cooldownMin...Constants.cooldownMax,
                    step: 0.1
                )
            }

            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Toggle dim:", name: .toggleDim)
            }

            Section("General") {
                Toggle("Enable Blackout", isOn: $settings.isEnabled)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        LoginItemManager.shared.setEnabled(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 680)
    }
}
