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

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "targetBrightness") == nil {
            defaults.set(Constants.defaultTargetBrightness, forKey: "targetBrightness")
        }
        if defaults.object(forKey: "isEnabled") == nil {
            defaults.set(true, forKey: "isEnabled")
        }

        self.targetBrightness = defaults.float(forKey: "targetBrightness")
        self.isEnabled = defaults.bool(forKey: "isEnabled")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }
}
