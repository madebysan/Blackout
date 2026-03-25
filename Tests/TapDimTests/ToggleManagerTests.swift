import XCTest
@testable import TapDim

final class ToggleManagerTests: XCTestCase {
    func testToggleManagerInitialState() {
        let manager = ToggleManager.shared
        XCTAssertFalse(manager.isDimmed, "Should start in non-dimmed state")
    }

    func testAppSettingsDefaults() {
        let settings = AppSettings.shared
        XCTAssertTrue(settings.isEnabled, "Should be enabled by default")
        XCTAssertEqual(settings.targetBrightness, Constants.defaultTargetBrightness, accuracy: 0.01, "Default target brightness should be 10%")
    }

    func testBrightnessControllerLoadsFramework() {
        let controller = BrightnessController.shared
        // DisplayServices framework should load on macOS
        XCTAssertTrue(controller.isAvailable, "BrightnessController should load DisplayServices framework")
    }

    func testBrightnessControllerReadBrightness() {
        let controller = BrightnessController.shared
        // Reading brightness may fail in test environments (headless, CI)
        // Just verify it doesn't crash — the value may be nil
        let _ = controller.currentBrightness()
    }

    func testConstantsRange() {
        XCTAssertEqual(Constants.targetBrightnessMin, 0.0)
        XCTAssertEqual(Constants.targetBrightnessMax, 0.50)
        XCTAssertGreaterThan(Constants.defaultTargetBrightness, Constants.targetBrightnessMin)
        XCTAssertLessThanOrEqual(Constants.defaultTargetBrightness, Constants.targetBrightnessMax)
    }
}
