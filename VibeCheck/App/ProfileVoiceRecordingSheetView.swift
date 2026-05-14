import SwiftUI

struct ProfileVoiceRecordingSheetView: View {
    @ObservedObject var recorder: ProfileVoiceSampleRecorder
    @Binding var isPresented: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var startRecordingPending = false

    private var inkOnSurface: Color {
        colorScheme == .dark ? Color.white.opacity(0.93) : Color(hex: 0x151C27)
    }

    private var inkOnSurfaceVariant: Color {
        colorScheme == .dark ? Color.white.opacity(0.64) : Color(hex: 0x434655)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Sesini Analiz Edelim")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(inkOnSurface)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                Text(recorder.sheetCountdownLabel)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x004BE3))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .padding(.bottom, 10)

                readingScriptSection
                    .padding(.bottom, 12)

                VoiceSheetWaveBarsView(
                    powerDb: recorder.averagePowerDb,
                    isRecording: recorder.isRecording
                )
                .frame(height: 84)
                .padding(.bottom, 14)

                HStack(spacing: 16) {
                    voiceSheetMetricPill(
                        symbol: "bolt.fill",
                        title: "Enerji",
                        circleFill: Color(hex: 0x00855B),
                        iconColor: .white,
                        border: nil,
                        showsGlow: true,
                        glow: Color(hex: 0x00855B).opacity(0.35)
                    )
                    voiceSheetMetricPill(
                        symbol: "waveform.circle.fill",
                        title: "Tonalite",
                        circleFill: Color(hex: 0x3366FF),
                        iconColor: .white,
                        border: nil,
                        showsGlow: true,
                        glow: Color(hex: 0x3366FF).opacity(0.3)
                    )
                    voiceSheetMetricPill(
                        symbol: "figure.run",
                        title: "Prosodi",
                        circleFill: colorScheme == .dark ? Color(hex: 0x2A3244).opacity(0.95) : Color(hex: 0xE2E8F8),
                        iconColor: inkOnSurfaceVariant,
                        border: Color(hex: 0xC3C5D8).opacity(colorScheme == .dark ? 0.45 : 0.85),
                        showsGlow: false,
                        glow: .clear
                    )
                }
                .opacity(recorder.isRecording ? 1 : 0.45)
                .padding(.bottom, 20)

                VStack(spacing: 8) {
                    if recorder.isRecording {
                        primaryRoundControlButton(symbol: "stop.fill", disabled: false) {
                            recorder.stopRecordingSaving()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                isPresented = false
                            }
                        }
                        Text("Kaydı Durdur")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(inkOnSurfaceVariant)
                    } else {
                        primaryRoundControlButton(
                            symbol: startRecordingPending ? "hourglass" : "mic.fill",
                            disabled: startRecordingPending
                        ) {
                            Task {
                                startRecordingPending = true
                                _ = await recorder.beginRecordingFromSheet()
                                startRecordingPending = false
                            }
                        }
                        Text("Kaydet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(inkOnSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Color.clear.frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(sheetFill.ignoresSafeArea())
        .onDisappear {
            recorder.stopRecordingSaving()
        }
        .onChange(of: recorder.isRecording) { wasRecording, isRec in
            if wasRecording, !isRec, recorder.hasSampleOnDisk {
                Task {
                    await VoiceAnalysisService.analyzeAndPersist(
                        readingPrompt: VoiceReadingPrompt.paragraph
                    )
                }
                Task {
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    await MainActor.run {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func primaryRoundControlButton(
        symbol: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 80, height: 80)
                .background(Circle().fill(Color(hex: 0x004BE3)))
                .shadow(color: Color(hex: 0x004BE3).opacity(0.32), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.52 : 1)
    }

    private var readingScriptSection: some View {
        VStack(spacing: 8) {
            Text("Okuma Metni")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(inkOnSurface)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(VoiceReadingPrompt.paragraph)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(inkOnSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color(hex: 0x2A3144).opacity(0.55)
                        : Color(hex: 0xF0F3FF)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: 0xC3C5D8).opacity(colorScheme == .dark ? 0.35 : 1), lineWidth: 1)
        )
    }

    private var sheetFill: Color {
        colorScheme == .dark ? Color(hex: 0x1C2230) : Color(hex: 0xF9F9FF)
    }

    private func voiceSheetMetricPill(
        symbol: String,
        title: String,
        circleFill: Color,
        iconColor: Color,
        border: Color?,
        showsGlow: Bool,
        glow: Color
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if showsGlow {
                    Circle()
                        .fill(glow)
                        .frame(width: 54, height: 54)
                        .blur(radius: 11)
                }
                Circle()
                    .fill(circleFill)
                    .frame(width: 48, height: 48)
                    .overlay {
                        if let border {
                            Circle().strokeBorder(border, lineWidth: 1)
                        }
                    }
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(inkOnSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VoiceSheetWaveBarsView: View {
    var powerDb: Float
    var isRecording: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let baseHeights: [CGFloat] = [8, 16, 20, 12, 24, 14, 6, 18, 10]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isRecording)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let voiceLift = CGFloat(min(1, max(0, Double(powerDb + 58) / 52)))

            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(baseHeights.enumerated()), id: \.offset) { index, rawH in
                        let rippleUp = CGFloat(abs(sin(phase * 7 + Double(index) * 0.65)))
                        let activeScale = isRecording
                            ? ((0.42 + 0.58 * voiceLift) * (1 + 0.18 * rippleUp))
                            : 0.42
                        let height = max(6, rawH * activeScale)

                        Capsule()
                            .fill(barColor(for: index))
                            .frame(width: 12, height: height)
                            .opacity(isRecording ? (0.52 + 0.48 * Double(voiceLift)) : 0.45)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            .frame(height: 96)
        }
    }

    private func barColor(for index: Int) -> Color {
        let primary = Color(hex: 0x004BE3)
        let container = Color(hex: 0x3366FF)
        let variant = Color(hex: 0xDCE2F3)
        let colors: [Color] = [
            container.opacity(0.65), primary.opacity(0.82), container,
            variant, primary, container.opacity(0.72), variant,
            primary.opacity(0.88), container.opacity(0.75),
        ]
        let c = colors[index % colors.count]
        return colorScheme == .dark ? c.opacity(0.92) : c
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
