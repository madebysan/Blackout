import CoreGraphics
import Foundation

final class BrightnessController {
    static let shared = BrightnessController()

    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias BrightnessChangedFn = @convention(c) (CGDirectDisplayID, Double) -> Void

    private let setBrightness: SetBrightnessFn?
    private let getBrightness: GetBrightnessFn?
    private let brightnessChanged: BrightnessChangedFn?

    private init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        )

        if let handle = handle {
            if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
                self.setBrightness = unsafeBitCast(sym, to: SetBrightnessFn.self)
            } else {
                self.setBrightness = nil
            }

            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                self.getBrightness = unsafeBitCast(sym, to: GetBrightnessFn.self)
            } else {
                self.getBrightness = nil
            }

            if let sym = dlsym(handle, "DisplayServicesBrightnessChanged") {
                self.brightnessChanged = unsafeBitCast(sym, to: BrightnessChangedFn.self)
            } else {
                self.brightnessChanged = nil
            }
        } else {
            self.setBrightness = nil
            self.getBrightness = nil
            self.brightnessChanged = nil
        }
    }

    var isAvailable: Bool {
        setBrightness != nil && getBrightness != nil
    }

    func currentBrightness() -> Float? {
        guard let getBrightness = getBrightness else { return nil }
        let display = CGMainDisplayID()
        var brightness: Float = 0
        let result = getBrightness(display, &brightness)
        guard result == 0 else { return nil }
        return brightness
    }

    func set(brightness: Float) {
        guard let setBrightness = setBrightness else { return }
        let display = CGMainDisplayID()
        let clamped = max(0.0, min(1.0, brightness))
        _ = setBrightness(display, clamped)
        brightnessChanged?(display, Double(clamped))
    }
}
