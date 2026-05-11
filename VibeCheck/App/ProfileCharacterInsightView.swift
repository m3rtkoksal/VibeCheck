import SwiftUI

/// Profil tabında kayıtlı karakter özetini gösterir; profil değişince yenileme ister.
struct ProfileCharacterInsightView: View {
    @AppStorage("profile.privateNote") private var privateNote = ""
    @State private var payload: SelfProfileInsightStore.Payload?
    @State private var isRefreshing = false
    @State private var errorText: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var palette: CharacterInsightChromePalette {
        colorScheme == .dark ? .dark : .light
    }

    /// Alt kapsül düğme: yalnızca analiz yok / profil değişmiş / hata / yenileme sırasında.
    private var showsBottomPrimaryAction: Bool {
        if errorText != nil { return true }
        if isRefreshing { return true }
        if payload?.insight == nil { return true }
        return SelfProfileInsightStore.isStaleComparedToProfile()
    }

    private var scrollBottomPadding: CGFloat {
        showsBottomPrimaryAction ? 110 : 28
    }

    var body: some View {
        profileInsightRoot
    }

    private var profileInsightRoot: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                stickyHeader
                profileInsightScroll
            }
        }
        .tint(Color(hex: 0x2563EB))
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsBottomPrimaryAction {
                primaryActionDock
            }
        }
        .overlay {
            if isRefreshing {
                analysisLoadingOverlay
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isRefreshing)
        .onAppear {
            reloadFromStore()
        }
    }

    private var profileInsightScroll: some View {
        ScrollView {
            profileInsightScrollContent
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, scrollBottomPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.clear)
    }

    @ViewBuilder
    private var profileInsightScrollContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if SelfProfileInsightStore.isStaleComparedToProfile(),
               payload?.insight != nil {
                staleBanner
            }

            if let errorText {
                profileErrorCallout(errorText)
            }

            if let insight = payload?.insight {
                SelfProfileInsightSections(insight: insight, bottomSpacerMin: 8)

                if let savedAt = payload?.savedAt {
                    Text(savedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
            } else {
                ContentUnavailableView(
                    "Henüz özet yok",
                    systemImage: "sparkles",
                    description: Text(
                        "Profil analizi tamamlanınca burada saklanır. "
                            + "Aşağıdan şimdi de oluşturabilirsin."
                    )
                )
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func profileErrorCallout(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 15))
            .foregroundStyle(CharacterInsightChromePalette.errorInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CharacterInsightChromePalette.errorContainerFill.opacity(0.35))
            )
    }

    // MARK: - Üst çubuk

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            HarmonyPanelChrome.toolbarBackGlass(
                                diameter: 36,
                                colorScheme: colorScheme,
                                reduceTransparency: reduceTransparency
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Geri")

                Spacer(minLength: 0)

                characterInsightToolbarTitle

                Spacer(minLength: 0)

                Color.clear
                    .frame(width: 36, height: 36)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)

            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    private var characterInsightToolbarTitle: some View {
        Text("Karakter Özetin")
            .font(.system(size: 19, weight: .heavy, design: .default))
            .tracking(-0.45)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .shadow(color: insightNavTitleShadowPrimary, radius: 0, x: 0, y: 1)
            .shadow(color: insightNavTitleShadowSecondary, radius: 2, x: 0, y: 0)
            .shadow(color: insightNavTitleShadowHighlight, radius: 1, x: 0, y: -0.5)
    }

    private var insightNavTitleShadowPrimary: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.22)
    }

    private var insightNavTitleShadowSecondary: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08)
    }

    private var insightNavTitleShadowHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.clear
    }

    private var analysisLoadingOverlay: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.42 : 0.28))
                .ignoresSafeArea()

            VStack(spacing: 20) {
                LottieAnimationPlayer(animationName: "loading")
                    .frame(width: 200, height: 200)

                Text("Analiz yenileniyor…")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analiz yenileniyor")
    }

    private var staleBanner: some View {
        Text(
            "Sorularından veya özel notundan biri değişti. "
                + "Güncel özeti görmek için analizi yenile."
        )
        .font(.system(size: 15))
        .foregroundStyle(palette.bannerText)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CharacterInsightChromePalette.bannerFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(CharacterInsightChromePalette.bannerStroke, lineWidth: 1)
                )
        )
    }

    private var primaryActionDock: some View {
        Button {
            Task { await refreshInsight() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 21, weight: .medium))

                Text(bottomButtonTitle)
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 28, colorScheme: colorScheme))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14),
                radius: 14,
                x: 0,
                y: 6
            )
        }
        .buttonStyle(ProfileInsightPrimaryTapStyle(scale: 0.97))
        .disabled(isRefreshing)
        .opacity(isRefreshing ? 0.55 : 1)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var bottomButtonTitle: String {
        if payload == nil {
            return "Analiz oluştur"
        }
        if SelfProfileInsightStore.isStaleComparedToProfile() {
            return "Analizi yenile"
        }
        return "Analizi yeniden çalıştır"
    }

    private func reloadFromStore() {
        payload = SelfProfileInsightStore.load()
    }

    private func refreshInsight() async {
        errorText = nil
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let me = ProfileSnapshot.fromLocalDefaults()
            let insight = try await AICompatibilityService.analyzeSelfProfile(
                me: me,
                privateNote: privateNote
            )
            SelfProfileInsightStore.save(insight: insight)
            reloadFromStore()
        } catch {
            errorText =
                FriendlyCallableError.message(for: error, label: "Profil analizi")
        }
    }
}

// MARK: - Chrome palet ve basınç

private enum CharacterInsightChromePalette {
    case light
    case dark

    var secondaryLabel: Color {
        switch self {
        case .light: return Color(hex: 0x475569).opacity(0.85)
        case .dark: return Color(hex: 0x94A3B8)
        }
    }

    var bannerText: Color {
        switch self {
        case .light: return Color(hex: 0x334155)
        case .dark: return Color(hex: 0xE2E8F0)
        }
    }

    static let bannerFill = Color(hex: 0xEFF6FF)
    static let bannerStroke = Color(hex: 0x93C5FD).opacity(0.45)
    static let errorInk = Color(hex: 0xB45309)
    static let errorContainerFill = Color(hex: 0xDBEAFE)
}

private struct ProfileInsightPrimaryTapStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.17), value: configuration.isPressed)
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

#Preview {
    NavigationStack {
        ProfileCharacterInsightView()
    }
}
