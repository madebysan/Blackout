import Foundation
import IOKit
import IOKit.hid

final class TapDetector {
    static let shared = TapDetector()

    private var manager: IOHIDManager?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?

    // Tap detection state
    private var tapTimes: [TimeInterval] = []
    private var lastTriggerTime: TimeInterval = 0
    private var isRunning = false

    // Callback when a double-tap is detected
    var onDoubleTap: (() -> Void)?

    private let settings = AppSettings.shared

    private(set) var isAvailable = false
    private(set) var permissionNeeded = false

    private init() {}

    func start() {
        guard !isRunning else { return }

        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = manager else { return }

        // Match the Apple Silicon accelerometer: vendor usage page 0xFF00, usage 3
        let matchDict: [String: Any] = [
            kIOHIDPrimaryUsagePageKey as String: 0xFF00,
            kIOHIDPrimaryUsageKey as String: 3
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)

        // Register callback BEFORE opening (required for reports to flow)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputReportCallback(manager, hidReportCallback, context)

        // Schedule on main run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // Open with SeizeDevice — this is the key to getting reports on Apple Silicon
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if openResult != kIOReturnSuccess {
            print("TapDetector: Failed to open IOHIDManager (result: \(openResult))")
            permissionNeeded = (openResult == -536870174) // kIOReturnNotPermitted
            isAvailable = false
            return
        }

        // Verify devices matched
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              !deviceSet.isEmpty else {
            print("TapDetector: No accelerometer device found")
            isAvailable = false
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return
        }

        isRunning = true
        isAvailable = true
        permissionNeeded = false
        print("TapDetector: Accelerometer active (\(deviceSet.count) devices)")
    }

    func stop() {
        guard isRunning, let manager = manager else { return }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        self.manager = nil
        reportBuffer?.deallocate()
        reportBuffer = nil
        isRunning = false
    }

    fileprivate func processReport(_ report: UnsafeMutablePointer<UInt8>, length: Int) {
        guard length >= 18, settings.isEnabled else { return }

        // Parse X, Y, Z from the 22-byte HID report
        // int32 little-endian at offsets 6, 10, 14
        var xRaw: Int32 = 0
        var yRaw: Int32 = 0
        var zRaw: Int32 = 0
        memcpy(&xRaw, report.advanced(by: 6), 4)
        memcpy(&yRaw, report.advanced(by: 10), 4)
        memcpy(&zRaw, report.advanced(by: 14), 4)
        let x = Int32(littleEndian: xRaw)
        let y = Int32(littleEndian: yRaw)
        let z = Int32(littleEndian: zRaw)

        // Convert to g-force
        let scale = 65536.0
        let gX = Double(x) / scale
        let gY = Double(y) / scale
        let gZ = Double(z) / scale

        // Compute magnitude (subtract ~1g gravity baseline)
        let magnitude = sqrt(gX * gX + gY * gY + gZ * gZ)
        let deviation = abs(magnitude - 1.0)

        let now = ProcessInfo.processInfo.systemUptime
        let threshold = Double(settings.tapSensitivity)
        let tapWindow = settings.tapWindow
        let cooldown = settings.cooldown

        // Check if this is a tap (spike above threshold)
        guard deviation > threshold else { return }

        // Cooldown check — don't retrigger too fast
        guard (now - lastTriggerTime) > cooldown else { return }

        let tapsRequired = settings.tapsRequired

        // Remove stale taps outside the window
        tapTimes = tapTimes.filter { (now - $0) < tapWindow }

        // Minimum gap between taps to avoid counting the same impact twice
        if let lastTap = tapTimes.last, (now - lastTap) < 0.05 {
            return
        }

        tapTimes.append(now)

        if tapTimes.count >= tapsRequired {
            // Required taps detected!
            lastTriggerTime = now
            tapTimes.removeAll()

            DispatchQueue.main.async { [weak self] in
                self?.onDoubleTap?()
            }
        }
    }
}

// C-style callback for IOKit HID
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
