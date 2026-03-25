import Foundation

enum Constants {
    static let defaultTargetBrightness: Float = 0.10
    static let targetBrightnessMin: Float = 0.0
    static let targetBrightnessMax: Float = 0.50

    // Tap detection defaults
    static let defaultTapSensitivity: Float = 0.15    // g-force threshold
    static let tapSensitivityMin: Float = 0.02
    static let tapSensitivityMax: Float = 0.50

    static let defaultTapWindow: Double = 0.4          // seconds between taps
    static let tapWindowMin: Double = 0.2
    static let tapWindowMax: Double = 0.8

    static let defaultCooldown: Double = 1.0           // seconds after trigger
    static let cooldownMin: Double = 0.3
    static let cooldownMax: Double = 3.0
}
