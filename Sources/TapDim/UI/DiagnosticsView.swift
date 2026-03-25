import SwiftUI
import IOKit
import IOKit.hid

struct DiagnosticsView: View {
    @State private var log: [String] = []
    @State private var isRunning = false
    @State private var isTapTest = false
    @State private var tapTestReports = 0
    @State private var tapTestMaxDev: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diagnostics")
                    .font(.headline)
                Spacer()
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(log.enumerated()), id: \.offset) { i, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(lineColor(line))
                                .textSelection(.enabled)
                                .id(i)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 350)
                .padding(8)
                .background(.black.opacity(0.3))
                .cornerRadius(8)
                .onChange(of: log.count) { _, _ in
                    if let last = log.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            HStack {
                Button("Run All Tests") {
                    runAllTests()
                }
                .disabled(isRunning)

                Button("5s Tap Test") {
                    runTapTest()
                }
                .disabled(isRunning)

                Spacer()

                Button("Copy Log") {
                    let text = log.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }
        .padding(16)
        .frame(width: 520, height: 480)
    }

    private func lineColor(_ line: String) -> Color {
        if line.starts(with: "PASS") { return .green }
        if line.starts(with: "FAIL") { return .red }
        if line.starts(with: "WARN") { return .orange }
        if line.starts(with: "SPIKE") { return .yellow }
        if line.starts(with: "---") { return .secondary }
        return .primary
    }

    private func addLog(_ text: String) {
        DispatchQueue.main.async {
            log.append(text)
        }
    }

    private func runAllTests() {
        log.removeAll()
        isRunning = true

        DispatchQueue.global(qos: .userInitiated).async {
            // 1. System info
            addLog("--- SYSTEM INFO ---")
            var size = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            var model = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            addLog("Model: \(String(cString: model))")

            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            addLog("macOS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
            addLog("CPU: \(ProcessInfo.processInfo.processorCount) cores")
            addLog("")

            // 2. IOKit device enumeration
            addLog("--- IOKIT DEVICE SCAN ---")
            let matching = IOServiceMatching("AppleSPUHIDDevice")
            var iterator: io_iterator_t = 0
            let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
            addLog("IOServiceGetMatchingServices: \(kr == 0 ? "OK" : "FAILED (\(kr))")")

            var deviceIndex = 0
            var service = IOIteratorNext(iterator)
            while service != 0 {
                deviceIndex += 1
                var props: Unmanaged<CFMutableDictionary>?
                IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
                if let dict = props?.takeRetainedValue() as? [String: Any] {
                    let usage = dict["PrimaryUsage"] as? Int ?? -1
                    let usagePage = dict["PrimaryUsagePage"] as? Int ?? -1
                    let maxInput = dict["MaxInputReportSize"] as? Int ?? -1
                    let product = dict["Product"] as? String ?? "(none)"
                    addLog("  Device #\(deviceIndex): usage=\(usage) page=0x\(String(usagePage, radix: 16)) maxInput=\(maxInput) product=\(product)")
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            addLog(deviceIndex > 0 ? "PASS \(deviceIndex) SPU HID devices found" : "FAIL No SPU HID devices found")
            addLog("")

            // 3. HID Manager - match usage 3 only
            addLog("--- HID MANAGER (usage=3) ---")
            let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let matchDict: [String: Any] = [
                kIOHIDPrimaryUsagePageKey as String: 0xFF00,
                kIOHIDPrimaryUsageKey as String: 3
            ]
            IOHIDManagerSetDeviceMatching(mgr, matchDict as CFDictionary)
            IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

            // Try seize
            let seizeResult = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
            addLog("Open(SeizeDevice): \(seizeResult) \(seizeResult == 0 ? "OK" : "FAILED")")

            if seizeResult != 0 {
                IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
                let normalResult = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
                addLog("Open(Normal): \(normalResult) \(normalResult == 0 ? "OK" : "FAILED")")
            }

            if let devices = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> {
                addLog("Matched devices: \(devices.count)")
                for device in devices {
                    let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "(unknown)"
                    let maxIn = IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int ?? -1
                    addLog("  \(name) | maxInput=\(maxIn)")
                }
            } else {
                addLog("FAIL No devices matched")
            }
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            addLog("")

            // 4. HID Manager - match ALL on 0xFF00
            addLog("--- HID MANAGER (all 0xFF00) ---")
            let mgr2 = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let broadMatch: [String: Any] = [
                kIOHIDPrimaryUsagePageKey as String: 0xFF00
            ]
            IOHIDManagerSetDeviceMatching(mgr2, broadMatch as CFDictionary)
            IOHIDManagerScheduleWithRunLoop(mgr2, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            let openResult2 = IOHIDManagerOpen(mgr2, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
            addLog("Open(SeizeDevice): \(openResult2)")

            if let devices2 = IOHIDManagerCopyDevices(mgr2) as? Set<IOHIDDevice> {
                addLog("Total 0xFF00 devices: \(devices2.count)")
                for device in devices2 {
                    let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "(unknown)"
                    let usage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int ?? -1
                    let maxIn = IOHIDDeviceGetProperty(device, kIOHIDMaxInputReportSizeKey as CFString) as? Int ?? -1
                    addLog("  usage=\(usage) maxIn=\(maxIn) \(name)")
                }
            }
            IOHIDManagerClose(mgr2, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(mgr2, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            addLog("")

            // 5. Quick data test (2 seconds)
            addLog("--- DATA STREAM TEST (2s) ---")
            addLog("Listening for reports...")

            let testMgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerSetDeviceMatching(testMgr, matchDict as CFDictionary)

            var reportCount = 0
            var maxDev: Double = 0
            var reportLengths = [Int: Int]()
            var firstReportBytes = ""

            IOHIDManagerRegisterInputReportCallback(testMgr, { ctx, res, sender, type, rid, report, len in
                let c = ctx!.assumingMemoryBound(to: Int.self)
                c.pointee += 1

                if c.pointee == 1 {
                    // Capture first report raw bytes
                    var bytes = [String]()
                    for i in 0..<min(len, 22) {
                        bytes.append(String(format: "%02X", report[i]))
                    }
                    // Store in a global-ish way via UserDefaults (hacky but works)
                    UserDefaults.standard.set(bytes.joined(separator: " "), forKey: "_diag_first_report")
                    UserDefaults.standard.set(len, forKey: "_diag_report_len")
                }

                if len >= 18 {
                    var xR: Int32 = 0; var yR: Int32 = 0; var zR: Int32 = 0
                    memcpy(&xR, report.advanced(by: 6), 4)
                    memcpy(&yR, report.advanced(by: 10), 4)
                    memcpy(&zR, report.advanced(by: 14), 4)
                    let s = 65536.0
                    let mag = sqrt(pow(Double(Int32(littleEndian: xR))/s, 2) + pow(Double(Int32(littleEndian: yR))/s, 2) + pow(Double(Int32(littleEndian: zR))/s, 2))
                    let dev = abs(mag - 1.0)
                    let currentMax = UserDefaults.standard.double(forKey: "_diag_max_dev")
                    if dev > currentMax {
                        UserDefaults.standard.set(dev, forKey: "_diag_max_dev")
                    }
                }
            }, &reportCount)

            IOHIDManagerScheduleWithRunLoop(testMgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            let testOpen = IOHIDManagerOpen(testMgr, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
            addLog("Open: \(testOpen)")

            UserDefaults.standard.set("", forKey: "_diag_first_report")
            UserDefaults.standard.set(0, forKey: "_diag_report_len")
            UserDefaults.standard.set(0.0, forKey: "_diag_max_dev")

            // Wait 2 seconds then report
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let finalCount = reportCount
                let firstReport = UserDefaults.standard.string(forKey: "_diag_first_report") ?? ""
                let reportLen = UserDefaults.standard.integer(forKey: "_diag_report_len")
                let maxDevSeen = UserDefaults.standard.double(forKey: "_diag_max_dev")

                IOHIDManagerClose(testMgr, IOOptionBits(kIOHIDOptionsTypeNone))
                IOHIDManagerUnscheduleFromRunLoop(testMgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

                if finalCount > 0 {
                    addLog("PASS \(finalCount) reports in 2s (~\(finalCount/2) Hz)")
                    addLog("Report length: \(reportLen) bytes")
                    addLog("First report: \(firstReport)")
                    addLog("Max deviation: \(String(format: "%.4f", maxDevSeen))g")
                } else {
                    addLog("FAIL 0 reports received in 2 seconds")
                    addLog("The sensor opens but does not stream data on this Mac.")
                    addLog("This is a known issue with some M1/M1 Pro models.")
                }
                addLog("")

                // 6. Current app state
                addLog("--- APP STATE ---")
                let detector = TapDetector.shared
                addLog("TapDetector.isAvailable: \(detector.isAvailable)")
                addLog("TapDetector.permissionNeeded: \(detector.permissionNeeded)")
                addLog("TapDetector.startError: \(detector.startError ?? "none")")

                let settings = AppSettings.shared
                addLog("Settings.isEnabled: \(settings.isEnabled)")
                addLog("Settings.tapsRequired: \(settings.tapsRequired)")
                addLog("Settings.tapSensitivity: \(settings.tapSensitivity)g")
                addLog("Settings.tapWindow: \(settings.tapWindow)s")
                addLog("Settings.cooldown: \(settings.cooldown)s")
                addLog("")

                // 7. Brightness
                addLog("--- BRIGHTNESS ---")
                let bc = BrightnessController.shared
                addLog("BrightnessController.isAvailable: \(bc.isAvailable)")
                if let brightness = bc.currentBrightness() {
                    addLog("Current brightness: \(String(format: "%.2f", brightness))")
                } else {
                    addLog("WARN Cannot read brightness")
                }

                addLog("")
                addLog("--- DONE ---")
                addLog("Copy this log and share it for debugging.")

                isRunning = false
            }
        }
    }

    private func runTapTest() {
        log.removeAll()
        isRunning = true
        isTapTest = true
        tapTestReports = 0
        tapTestMaxDev = 0

        addLog("--- TAP TEST (5 seconds) ---")
        addLog("TAP THE MACBOOK NOW! Watching for spikes...")
        addLog("")

        let testMgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchDict: [String: Any] = [
            kIOHIDPrimaryUsagePageKey as String: 0xFF00,
            kIOHIDPrimaryUsageKey as String: 3
        ]
        IOHIDManagerSetDeviceMatching(testMgr, matchDict as CFDictionary)

        var count = 0
        IOHIDManagerRegisterInputReportCallback(testMgr, { ctx, res, sender, type, rid, report, len in
            let c = ctx!.assumingMemoryBound(to: Int.self)
            c.pointee += 1

            if len >= 18 {
                var xR: Int32 = 0; var yR: Int32 = 0; var zR: Int32 = 0
                memcpy(&xR, report.advanced(by: 6), 4)
                memcpy(&yR, report.advanced(by: 10), 4)
                memcpy(&zR, report.advanced(by: 14), 4)
                let s = 65536.0
                let gX = Double(Int32(littleEndian: xR)) / s
                let gY = Double(Int32(littleEndian: yR)) / s
                let gZ = Double(Int32(littleEndian: zR)) / s
                let mag = sqrt(gX*gX + gY*gY + gZ*gZ)
                let dev = abs(mag - 1.0)

                let currentMax = UserDefaults.standard.double(forKey: "_diag_tap_max")
                if dev > currentMax {
                    UserDefaults.standard.set(dev, forKey: "_diag_tap_max")
                }

                if dev > 0.02 {
                    DispatchQueue.main.async {
                        // Use notification to pass data back
                        NotificationCenter.default.post(name: .init("DiagSpike"), object: nil, userInfo: [
                            "dev": dev, "x": gX, "y": gY, "z": gZ, "count": c.pointee
                        ])
                    }
                }
            }
        }, &count)

        // Listen for spikes
        let observer = NotificationCenter.default.addObserver(forName: .init("DiagSpike"), object: nil, queue: .main) { notif in
            if let info = notif.userInfo,
               let dev = info["dev"] as? Double,
               let x = info["x"] as? Double,
               let y = info["y"] as? Double,
               let z = info["z"] as? Double {
                addLog("SPIKE dev=\(String(format:"%.4f", dev))g | X=\(String(format:"%.3f",x)) Y=\(String(format:"%.3f",y)) Z=\(String(format:"%.3f",z))")
            }
        }

        IOHIDManagerScheduleWithRunLoop(testMgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        UserDefaults.standard.set(0.0, forKey: "_diag_tap_max")
        let openResult = IOHIDManagerOpen(testMgr, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        addLog("Open: \(openResult)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            let finalCount = count
            let maxDev = UserDefaults.standard.double(forKey: "_diag_tap_max")

            IOHIDManagerClose(testMgr, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(testMgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            NotificationCenter.default.removeObserver(observer)

            addLog("")
            addLog("Total reports: \(finalCount)")
            addLog("Max deviation: \(String(format: "%.4f", maxDev))g")

            if finalCount == 0 {
                addLog("FAIL No data from sensor. Tap detection will not work on this Mac.")
            } else if maxDev < 0.05 {
                addLog("WARN Data streaming but no significant spikes detected. Try tapping harder.")
            } else {
                addLog("PASS Spikes detected! Tap detection should work.")
            }

            addLog("")
            addLog("Copy this log and share it for debugging.")
            isRunning = false
            isTapTest = false
        }
    }
}
