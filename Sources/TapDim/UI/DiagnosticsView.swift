import SwiftUI
import IOKit
import IOKit.hid

struct DiagnosticsView: View {
    @State private var log: [String] = []
    @State private var isRunning = false

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
            addLog("")

            // 2. IOKit device scan
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
                    addLog("  #\(deviceIndex): usage=\(usage) page=0x\(String(usagePage, radix: 16)) maxInput=\(maxInput)")
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            addLog(deviceIndex > 0 ? "PASS \(deviceIndex) SPU devices found" : "FAIL No SPU devices")
            addLog("")

            // 3. App's own TapDetector state
            addLog("--- TAP DETECTOR STATE ---")
            let detector = TapDetector.shared
            addLog("isAvailable: \(detector.isAvailable)")
            addLog("permissionNeeded: \(detector.permissionNeeded)")
            addLog("startError: \(detector.startError ?? "none")")
            addLog("Reports received so far: \(detector.reportCount)")
            addLog("Max deviation seen: \(String(format: "%.4f", detector.maxDeviation))g")
            addLog("Spikes (>0.03g): \(detector.spikeCount)")
            addLog("")

            // 4. Live report counter (5 seconds)
            addLog("--- LIVE DATA TEST (5s) ---")
            addLog("TAP YOUR MACBOOK NOW!")
            let startCount = detector.reportCount
            let startSpikes = detector.spikeCount
            let startMax = detector.maxDeviation
            addLog("Starting report count: \(startCount)")

            // Check every second for 5 seconds
            for i in 1...5 {
                Thread.sleep(forTimeInterval: 1.0)
                let currentCount = detector.reportCount
                let currentSpikes = detector.spikeCount
                let newReports = currentCount - startCount
                let newSpikes = currentSpikes - startSpikes
                addLog("  \(i)s: +\(newReports) reports, +\(newSpikes) spikes, max=\(String(format: "%.4f", detector.maxDeviation))g, last=\(String(format: "%.4f", detector.lastDeviation))g")
            }

            let totalNewReports = detector.reportCount - startCount
            let totalNewSpikes = detector.spikeCount - startSpikes

            addLog("")
            if totalNewReports == 0 {
                addLog("FAIL 0 reports in 5s — sensor is not streaming data")
                addLog("The accelerometer opened but sends no data on this Mac model.")
            } else if totalNewSpikes == 0 {
                addLog("WARN \(totalNewReports) reports but 0 spikes — try tapping harder")
                addLog("Data is streaming but no taps detected above 0.03g threshold")
            } else {
                addLog("PASS \(totalNewReports) reports, \(totalNewSpikes) spikes detected")
                addLog("Max deviation: \(String(format: "%.4f", detector.maxDeviation))g")
            }
            addLog("")

            // 5. Settings
            addLog("--- SETTINGS ---")
            let settings = AppSettings.shared
            addLog("isEnabled: \(settings.isEnabled)")
            addLog("tapsRequired: \(settings.tapsRequired)")
            addLog("tapSensitivity: \(settings.tapSensitivity)g")
            addLog("tapWindow: \(settings.tapWindow)s")
            addLog("cooldown: \(settings.cooldown)s")
            addLog("")

            // 6. Brightness
            addLog("--- BRIGHTNESS ---")
            let bc = BrightnessController.shared
            addLog("isAvailable: \(bc.isAvailable)")
            if let b = bc.currentBrightness() {
                addLog("Current: \(String(format: "%.2f", b))")
            } else {
                addLog("WARN Cannot read brightness")
            }

            addLog("")
            addLog("--- DONE ---")
            addLog("Press 'Copy Log' and share for debugging.")

            DispatchQueue.main.async { isRunning = false }
        }
    }
}
