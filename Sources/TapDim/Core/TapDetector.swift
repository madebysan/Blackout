import Foundation
import IOKit
import IOKit.hid

final class TapDetector {
    static let shared = TapDetector()

    private var manager: IOHIDManager?

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
    private(set) var startError: String?
    private(set) var reportCount = 0
    private(set) var maxDeviation: Double = 0
    private(set) var lastDeviation: Double = 0
    private(set) var spikeCount = 0

    private init() {}

    func start() {
        guard !isRunning else { return }

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

        // Schedule on main run loop
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

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

        // Check if any devices matched
        if let deviceSet = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>, !deviceSet.isEmpty {
            isRunning = true
            isAvailable = true
            permissionNeeded = false
            startError = nil
            print("TapDetector: Accelerometer active (\(deviceSet.count) devices)")
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
        IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        manager = nil
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
