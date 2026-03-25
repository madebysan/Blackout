import Foundation
import IOKit
import IOKit.hid

final class TapDetector {
    static let shared = TapDetector()

    private var manager: IOHIDManager?
    private var reportBuffer = [UInt8](repeating: 0, count: 64)

    // Tap detection state
    private var lastTapTime: TimeInterval = 0
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

        // Schedule on main run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // Try to open — this is where Input Monitoring permission is checked
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("TapDetector: Failed to open IOHIDManager (result: \(openResult)). Input Monitoring permission may be needed.")
            permissionNeeded = true
            isAvailable = false
            return
        }

        // Get matched devices
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = deviceSet.first else {
            print("TapDetector: No accelerometer device found. This Mac may not have one.")
            isAvailable = false
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return
        }

        // Register input report callback
        let context = Unmanaged.passUnretained(self).toOpaque()
        reportBuffer.withUnsafeMutableBufferPointer { buffer in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                buffer.baseAddress!,
                buffer.count,
                hidReportCallback,
                context
            )
        }

        isRunning = true
        isAvailable = true
        permissionNeeded = false
        print("TapDetector: Accelerometer active")
    }

    func stop() {
        guard isRunning, let manager = manager else { return }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        self.manager = nil
        isRunning = false
        print("TapDetector: Stopped")
    }

    fileprivate func processReport(_ report: UnsafePointer<UInt8>, length: Int) {
        guard length >= 18, settings.isEnabled else { return }

        // Parse X, Y, Z from the 22-byte HID report
        // int32 little-endian at offsets 6, 10, 14
        let x = report.advanced(by: 6).withMemoryRebound(to: Int32.self, capacity: 1) { Int32(littleEndian: $0.pointee) }
        let y = report.advanced(by: 10).withMemoryRebound(to: Int32.self, capacity: 1) { Int32(littleEndian: $0.pointee) }
        let z = report.advanced(by: 14).withMemoryRebound(to: Int32.self, capacity: 1) { Int32(littleEndian: $0.pointee) }

        // Convert to g-force
        let scale = 65536.0
        let gX = Double(x) / scale
        let gY = Double(y) / scale
        let gZ = Double(z) / scale

        // Compute magnitude (subtract ~1g gravity baseline)
        let magnitude = sqrt(gX * gX + gY * gY + gZ * gZ)
        let deviation = abs(magnitude - 1.0) // deviation from resting state (1g gravity)

        let now = ProcessInfo.processInfo.systemUptime
        let threshold = Double(settings.tapSensitivity)
        let tapWindow = settings.tapWindow
        let cooldown = settings.cooldown

        // Check if this is a tap (spike above threshold)
        guard deviation > threshold else { return }

        // Cooldown check — don't retrigger too fast
        guard (now - lastTriggerTime) > cooldown else { return }

        // Check for double-tap: second spike within the tap window
        let timeSinceLastTap = now - lastTapTime

        if timeSinceLastTap < tapWindow && timeSinceLastTap > 0.05 {
            // Double-tap detected!
            lastTriggerTime = now
            lastTapTime = 0 // reset so next tap starts fresh

            DispatchQueue.main.async { [weak self] in
                self?.onDoubleTap?()
            }
        } else {
            // First tap — record time
            lastTapTime = now
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
