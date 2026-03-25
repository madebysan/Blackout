import Foundation

final class ToggleManager: ObservableObject {
    static let shared = ToggleManager()

    @Published private(set) var isDimmed = false

    private var savedBrightness: Float = 1.0
    private let brightness = BrightnessController.shared
    private let settings = AppSettings.shared

    private init() {}

    func toggle() {
        guard settings.isEnabled else { return }

        if isDimmed {
            restore()
        } else {
            dim()
        }
    }

    private func dim() {
        guard let current = brightness.currentBrightness() else { return }
        savedBrightness = current
        brightness.set(brightness: settings.targetBrightness)
        isDimmed = true
    }

    private func restore() {
        brightness.set(brightness: savedBrightness)
        isDimmed = false
    }
}
