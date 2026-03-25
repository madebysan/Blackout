import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var targetBrightness: Float {
        didSet { UserDefaults.standard.set(targetBrightness, forKey: "targetBrightness") }
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var tapSensitivity: Float {
        didSet { UserDefaults.standard.set(tapSensitivity, forKey: "tapSensitivity") }
    }

    @Published var tapWindow: Double {
        didSet { UserDefaults.standard.set(tapWindow, forKey: "tapWindow") }
    }

    @Published var cooldown: Double {
        didSet { UserDefaults.standard.set(cooldown, forKey: "cooldown") }
    }

    @Published var tapsRequired: Int {
        didSet { UserDefaults.standard.set(tapsRequired, forKey: "tapsRequired") }
    }

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "targetBrightness") == nil {
            defaults.set(Constants.defaultTargetBrightness, forKey: "targetBrightness")
        }
        if defaults.object(forKey: "isEnabled") == nil {
            defaults.set(true, forKey: "isEnabled")
        }
        if defaults.object(forKey: "tapSensitivity") == nil {
            defaults.set(Constants.defaultTapSensitivity, forKey: "tapSensitivity")
        }
        if defaults.object(forKey: "tapWindow") == nil {
            defaults.set(Constants.defaultTapWindow, forKey: "tapWindow")
        }
        if defaults.object(forKey: "cooldown") == nil {
            defaults.set(Constants.defaultCooldown, forKey: "cooldown")
        }
        if defaults.object(forKey: "tapsRequired") == nil {
            defaults.set(Constants.defaultTapsRequired, forKey: "tapsRequired")
        }

        self.targetBrightness = defaults.float(forKey: "targetBrightness")
        self.isEnabled = defaults.bool(forKey: "isEnabled")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.tapSensitivity = defaults.float(forKey: "tapSensitivity")
        self.tapWindow = defaults.double(forKey: "tapWindow")
        self.cooldown = defaults.double(forKey: "cooldown")
        self.tapsRequired = defaults.integer(forKey: "tapsRequired")
    }
}
