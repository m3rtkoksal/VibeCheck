import SwiftUI

struct ProfileSummaryView: View {
    /// Snapshot of selections at the time the view is created.
    /// We still refresh from `UserDefaults` on appear to avoid SwiftUI capturing an early empty value.
    private let initialSelections: [String: String]
    @State private var selections: [String: String] = [:]
    @State private var isShowingCompatibility = false
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var discoverabilityVM = SettingsDetailViewModel()

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
            discoverabilityVM.syncFromFirebaseUser()
            Task { await discoverabilityVM.syncDiscoverabilityIndex() }
        }
        .navigationDestination(isPresented: $isShowingCompatibility) {
            SelfProfileAnalysisView()
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

            if selections.isEmpty {
                profileSummaryEmptyState
            } else {
                profileSummarySelectionsCard
            }
        }
        .frame(maxWidth: .infinity)
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

