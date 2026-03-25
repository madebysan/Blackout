import SwiftUI

struct WelcomeView: View {
    @ObservedObject private var settings = AppSettings.shared
    private let tapDetector = TapDetector.shared
    @State private var sensorChecked = false
    @State private var sensorAvailable = false
    @State private var tapDetected = false
    @State private var showGetStarted = false
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)

            // Icon
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)
                .padding(.bottom, 16)

            // Title
            Text("Welcome to TapDim")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 6)

            Text("Tap your MacBook. Screen goes dark.\nTap again. It comes back.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            // Steps
            VStack(alignment: .leading, spacing: 20) {
                // Step 1: Sensor check
                StepRow(
                    number: 1,
                    isComplete: sensorChecked && sensorAvailable,
                    isActive: true
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sensor check")
                            .font(.headline)

                        if !sensorChecked {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Checking hardware...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if sensorAvailable {
                            if tapDetected {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Tap detected — you're all set!")
                                        .foregroundStyle(.green)
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Accelerometer found")
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Text("👋")
                                    Text("Give your MacBook a tap!")
                                        .foregroundStyle(.primary)
                                }
                            }
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("No accelerometer found")
                                    .foregroundStyle(.secondary)
                            }
                            Text("Use the keyboard shortcut instead.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Step 2: Ready
                StepRow(
                    number: 2,
                    isComplete: false,
                    isActive: sensorChecked
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ready to go")
                            .font(.headline)
                            .foregroundStyle(sensorChecked ? .primary : .secondary)

                        if showGetStarted {
                            Text("TapDim lives in your menu bar. Adjust sensitivity and tap count in Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button(action: onDismiss) {
                                Text("Get Started")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .controlSize(.large)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(width: 400, height: 480)
        .onAppear {
            // Check sensor after a brief delay for visual feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sensorAvailable = tapDetector.isAvailable
                sensorChecked = true

                if sensorAvailable {
                    // Listen for a tap
                    let originalCallback = tapDetector.onDoubleTap
                    tapDetector.onDoubleTap = {
                        tapDetected = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showGetStarted = true
                        }
                        // Restore original callback
                        tapDetector.onDoubleTap = originalCallback
                    }
                } else {
                    showGetStarted = true
                }
            }
        }
    }
}

struct StepRow<Content: View>: View {
    let number: Int
    let isComplete: Bool
    let isActive: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : (isActive ? Color.indigo : Color.gray.opacity(0.3)))
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }

            content
                .padding(.top, 4)
        }
    }
}
