import Foundation
import IOKit
import IOKit.hid

final class TapDetector {
    static let shared = TapDetector()

    private var manager: IOHIDManager?
    private var hidQueue: DispatchQueue?

    // Tap detection state
    private var tapTimes: [TimeInterval] = []
    private var lastTriggerTime: TimeInterval = 0
    private var lastSpikeTime: TimeInterval = 0
    private var isInSpike = false
    private var isRunning = false

    // Callback when a tap trigger is detected
    var onDoubleTap: (() -> Void)?

    private(set) var isAvailable = false
    private(set) var permissionNeeded = false
    private(set) var isMotionRestricted = false
    private(set) var startError: String?
    private(set) var reportCount = 0
    private(set) var maxDeviation: Double = 0
    private(set) var lastDeviation: Double = 0
    private(set) var spikeCount = 0

    private init() {}

    /// Check if the accelerometer interface is marked as motion-restricted by macOS.
    /// macOS 26+ blocks third-party access to the accelerometer via this flag.
    private func checkMotionRestricted() -> Bool {
        guard let matching = IOServiceMatching("AppleSPUHIDInterface") else { return false }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == 0 else { return false }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }

            var nameBuffer = [CChar](repeating: 0, count: 128)
            IORegistryEntryGetName(service, &nameBuffer)
            let name = String(cString: nameBuffer)

            if name == "accel" {
                var props: Unmanaged<CFMutableDictionary>?
                IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
                if let dict = props?.takeRetainedValue() as? [String: Any],
                   let restricted = dict["motionRestrictedService"] as? Bool {
                    return restricted
                }
            }
        }
        return false
    }

    func start() {
        guard !isRunning else { return }

        // Check for macOS 26+ motion restriction before attempting to open
        if checkMotionRestricted() {
            isMotionRestricted = true
            startError = "macOS has restricted accelerometer access. Tap detection is unavailable — use the keyboard shortcut instead."
            print("TapDetector: \(startError!)")
            isAvailable = false
            return
        }

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr

        let matchDict: [String: Any] = [
            kIOHIDPrimaryUsagePageKey as String: 0xFF00,
            kIOHIDPrimaryUsageKey as String: 3
        ]
        IOHIDManagerSetDeviceMatching(mgr, matchDict as CFDictionary)

        // Register callback BEFORE opening
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputReportCallback(mgr, hidReportCallback, context)

        // Use dispatch queue API (required on macOS 26+, works on older versions too)
        let queue = DispatchQueue(label: "com.madebysan.blackout.hid", qos: .userInteractive)
        hidQueue = queue
        IOHIDManagerSetDispatchQueue(mgr, queue)

        // Try SeizeDevice first (required on some Macs), fall back to normal open
        var openResult = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if openResult != kIOReturnSuccess {
            print("TapDetector: SeizeDevice failed (\(openResult)), trying normal open...")
            openResult = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        if openResult != kIOReturnSuccess {
            if openResult == -536870203 { // kIOReturnExclusiveAccess
                startError = "Another app (e.g. SlapMac) has exclusive access to the accelerometer. Quit it and relaunch Blackout."
            } else {
                startError = "Failed to open HID manager (code: \(openResult))"
                permissionNeeded = true
            }
            print("TapDetector: \(startError!)")
            isAvailable = false
            cleanup()
            return
        }

        // Activate the manager (required when using dispatch queue)
        IOHIDManagerActivate(mgr)

        // Check if any devices matched
        if let deviceSet = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>, !deviceSet.isEmpty {
            isRunning = true
            isAvailable = true
            permissionNeeded = false
            isMotionRestricted = false
            startError = nil
            print("TapDetector: Accelerometer active (\(deviceSet.count) devices)")

            // Verify data is actually streaming after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if self.reportCount == 0 && self.isRunning {
                    // Device opened but no data — likely motion-restricted
                    self.isAvailable = false
                    self.isMotionRestricted = true
                    self.startError = "macOS has restricted accelerometer access. Tap detection is unavailable — use the keyboard shortcut instead."
                    print("TapDetector: No reports after 2s — accelerometer is restricted")
                    NotificationCenter.default.post(name: .tapDetectorStateChanged, object: nil)
                }
            }
        } else {
            startError = "No accelerometer device found on this Mac"
            print("TapDetector: \(startError!)")
            isAvailable = false
            cleanup()
        }
    }

    func stop() {
        cleanup()
        isRunning = false
    }

    private func cleanup() {
        guard let mgr = manager else { return }
        IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = nil
        hidQueue = nil
    }

    fileprivate func processReport(_ report: UnsafeMutablePointer<UInt8>, length: Int) {
        let settings = AppSettings.shared
        guard length >= 18, settings.isEnabled else { return }

        var xRaw: Int32 = 0
        var yRaw: Int32 = 0
        var zRaw: Int32 = 0
        memcpy(&xRaw, report.advanced(by: 6), 4)
        memcpy(&yRaw, report.advanced(by: 10), 4)
        memcpy(&zRaw, report.advanced(by: 14), 4)
        let x = Int32(littleEndian: xRaw)
        let y = Int32(littleEndian: yRaw)
        let z = Int32(littleEndian: zRaw)

        let scale = 65536.0
        let gX = Double(x) / scale
        let gY = Double(y) / scale
        let gZ = Double(z) / scale

        let magnitude = sqrt(gX * gX + gY * gY + gZ * gZ)
        let deviation = abs(magnitude - 1.0)

        reportCount += 1
        lastDeviation = deviation
        if deviation > maxDeviation { maxDeviation = deviation }
        if deviation > 0.03 { spikeCount += 1 }

        let now = ProcessInfo.processInfo.systemUptime
        let threshold = Double(settings.tapSensitivity)
        let tapWindow = settings.tapWindow
        let cooldown = settings.cooldown

        if deviation > threshold {
            lastSpikeTime = now
            if !isInSpike {
                isInSpike = true
            }
            return
        }

        let settleTime = 0.12
        if isInSpike && (now - lastSpikeTime) > settleTime {
            isInSpike = false

            guard (now - lastTriggerTime) > cooldown else { return }

            let tapsRequired = settings.tapsRequired

            tapTimes = tapTimes.filter { (now - $0) < tapWindow }
            tapTimes.append(lastSpikeTime)

            if tapTimes.count >= tapsRequired {
                lastTriggerTime = now
                tapTimes.removeAll()

                DispatchQueue.main.async { [weak self] in
                    self?.onDoubleTap?()
                }
            }
        }
    }
}

extension Notification.Name {
    static let tapDetectorStateChanged = Notification.Name("tapDetectorStateChanged")
}

private func hidReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context = context else { return }
    let detector = Unmanaged<TapDetector>.fromOpaque(context).takeUnretainedValue()
    detector.processReport(report, length: reportLength)
}
