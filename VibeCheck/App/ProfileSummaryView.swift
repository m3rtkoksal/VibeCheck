import Combine
import SwiftUI

struct ProfileSummaryView: View {
    /// Snapshot of selections at the time the view is created.
    /// We still refresh from `UserDefaults` on appear to avoid SwiftUI capturing an early empty value.
    private let initialSelections: [String: String]
    @State private var selections: [String: String] = [:]
    @State private var isShowingCompatibility = false
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var discoverabilityVM = SettingsDetailViewModel()
    @StateObject private var voiceSampleRecorder = ProfileVoiceSampleRecorder()
    @State private var showVoiceRecordingSheet = false
    @State private var hasVoiceProfileInsight = false

    init(selections: [String: String]) {
        self.initialSelections = selections
    }

    var body: some View {
        ScrollView {
            profileSummaryScrollContent
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.clear)
        .background(
            MeshAuroraBackgroundView()
                .ignoresSafeArea()
        )
        .navigationTitle("Hazırsın")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .tint(Color(hex: 0x2563EB))
        .onAppear {
            // Prefer fresh values; fixes empty summary when destination was constructed early.
            let fresh = ProfileEditorView.selectionsDictionary()
            selections = fresh.isEmpty ? initialSelections : fresh
            voiceSampleRecorder.refreshSavedState()
            refreshVoiceInsightState()
            discoverabilityVM.syncFromFirebaseUser()
            Task { await discoverabilityVM.syncDiscoverabilityIndex() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceProfileInsightDidUpdate)) { _ in
            refreshVoiceInsightState()
        }
        .alert("Ses Kaydı", isPresented: Binding(
            get: { voiceSampleRecorder.errorMessage != nil },
            set: { if !$0 { voiceSampleRecorder.errorMessage = nil } }
        )) {
            Button("Tamam") {
                voiceSampleRecorder.errorMessage = nil
            }
        } message: {
            Text(voiceSampleRecorder.errorMessage ?? "")
        }
        .navigationDestination(isPresented: $isShowingCompatibility) {
            SelfProfileAnalysisView()
        }
        .sheet(isPresented: $showVoiceRecordingSheet) {
            ProfileVoiceRecordingSheetView(
                recorder: voiceSampleRecorder,
                isPresented: $showVoiceRecordingSheet
            )
            .presentationDetents([.height(560), .large])
            .presentationCornerRadius(32)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isShowingCompatibility = true
            } label: {
                HStack(spacing: 8) {
                    Text("Analiz Et")
                        .font(.system(size: 17, weight: .semibold))
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 14, colorScheme: colorScheme))
                .shadow(color: summaryBottomCtaShadow, radius: 12, x: 0, y: 5)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var profileSummaryScrollContent: some View {
        VStack(alignment: .center, spacing: 18) {
            VStack(alignment: .center, spacing: 10) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 8, x: 0, y: 4)

                Text("Senin Profilin")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.6)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .shadow(color: summaryHeroShadowOuter, radius: 0, x: 0, y: 1)
                    .shadow(color: summaryHeroShadowMid, radius: 4, x: 0, y: 2)

                Text("Cevaplarına göre oluşturduğumuz özet.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            profileVoiceAnalysisCard

            if selections.isEmpty {
                profileSummaryEmptyState
            } else {
                profileSummarySelectionsCard
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var profileVoiceAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(hex: 0xA78BFA).opacity(colorScheme == .dark ? 0.28 : 0.22))
                    .frame(width: 120, height: 120)
                    .blur(radius: 42)
                    .offset(x: 36, y: -54)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x6366F1))

                        Text("Ses Analizi")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Opsiyonel")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                            )
                    }

                    Text(
                        "Sesinize dayalı karakter analizi için dilerseniz ses kaydı verebilirsiniz; "
                            + "isteğe bağlıdır."
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    voiceMetricBadgesRow

                    Button {
                        showVoiceRecordingSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 17, weight: .semibold))
                            Text(voiceSampleRecorder.hasSampleOnDisk ? "Tekrar Kaydet" : "Ses Kaydet")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(voiceRecordButtonBackground)
                        .shadow(
                            color: Color(hex: 0x6366F1).opacity(colorScheme == .dark ? 0.35 : 0.25),
                            radius: 12,
                            x: 0,
                            y: 5
                        )
                    }
                    .buttonStyle(.plain)

                    if voiceSampleRecorder.hasSampleOnDisk && !voiceSampleRecorder.isRecording {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: 0x22C55E))
                                Text("Kayıt alındı.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            if hasVoiceProfileInsight {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "waveform.circle.fill")
                                        .foregroundStyle(Color(hex: 0x6366F1))
                                        .font(.system(size: 13))
                                    Text(
                                        "Ses özeti oluşturuldu; gelecek analiz güncellemelerinde kullanılabilir."
                                    )
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 20, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.09 : 0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private var voiceMetricBadgesRow: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            voiceMetricBadge(title: "Enerji", dot: Color(hex: 0xFB923C))
            voiceMetricBadge(title: "Tonalite", dot: Color(hex: 0x38BDF8))
            voiceMetricBadge(title: "Prosodi", dot: Color(hex: 0xA78BFA))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func voiceMetricBadge(title: String, dot: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
                .tracking(0.3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.55), lineWidth: 1)
        )
    }

    private var voiceRecordButtonBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(
                LinearGradient(
                    colors: [Color(hex: 0x6366F1), Color(hex: 0xA855F7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            shape.fill(Material.ultraThinMaterial.opacity(colorScheme == .dark ? 0.22 : 0.14))
            shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        }
    }

    private var profileSummaryEmptyState: some View {
        Text("Özet için seçim bulunamadı. Profil ekranına dönüp seçimlerini kaydetmeyi deneyebilirsin.")
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 20, colorScheme: colorScheme)
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 12, x: 0, y: 5)
            )
    }

    private var profileSummarySelectionsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedSelections.enumerated()), id: \.offset) { idx, item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.key.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .kerning(0.4)

                    Text(item.value)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if idx < orderedSelections.count - 1 {
                    Rectangle()
                        .fill(summaryRowDividerFill)
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 20, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 6)
        )
        .frame(maxWidth: .infinity)
    }

    private var summaryHeroShadowOuter: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.14)
    }

    private var summaryHeroShadowMid: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.06)
    }

    private var summaryBottomCtaShadow: Color {
        Color.black.opacity(colorScheme == .dark ? 0.4 : 0.14)
    }

    private var summaryRowDividerFill: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08)
    }

    private var orderedSelections: [(key: String, value: String)] {
        let normalized = selections.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.value.isEmpty }
        var used = Set<String>()
        var result: [(key: String, value: String)] = []

        for category in ProfileCategory.allCases {
            if let value = normalized[category.title] {
                result.append((category.title, value))
                used.insert(category.title)
            }
        }

        let remaining = normalized.keys
            .filter { !used.contains($0) }
            .sorted()
            .map { ($0, normalized[$0] ?? "") }
        result.append(contentsOf: remaining)
        return result
    }

    private func refreshVoiceInsightState() {
        hasVoiceProfileInsight = VoiceProfileInsightStore.load() != nil
    }
}

#Preview {
    NavigationStack {
        ProfileSummaryView(selections: [
            "Sosyal enerji": "Ambivert",
            "Kıskançlık seviyesi": "Orta"
        ])
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

