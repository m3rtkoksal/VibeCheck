import SwiftUI

/// Profil tabında kayıtlı karakter özetini gösterir; profil değişince yenileme ister.
struct ProfileCharacterInsightView: View {
    @AppStorage("profile.privateNote") private var privateNote = ""
    @State private var payload: SelfProfileInsightStore.Payload?
    @State private var isRefreshing = false
    @State private var errorText: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

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
        ZStack {
            palette.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                stickyHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if SelfProfileInsightStore.isStaleComparedToProfile(),
                           payload?.insight != nil {
                            staleBanner
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.system(size: 15))
                                .foregroundStyle(CharacterInsightChromePalette.errorInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 18,
                                        style: .continuous
                                    )
                                    .fill(
                                        CharacterInsightChromePalette.errorContainerFill
                                            .opacity(0.35)
                                    )
                                )
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
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, scrollBottomPadding)
                }
            }
        }
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

    // MARK: - Üst çubuk

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(palette.headerIconMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text("Karakter Özetin")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF2D55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)

                Color.clear
                    .frame(width: 44, height: 44)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)

            Rectangle()
                .fill(palette.headerDivider.opacity(0.35))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial.opacity(colorScheme == .dark ? 0.82 : 0.88))
    }

    private var analysisLoadingOverlay: some View {
        ZStack {
            palette.pageBackground
                .opacity(colorScheme == .dark ? 0.92 : 0.96)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                LottieAnimationPlayer(animationName: "loading")
                    .frame(width: 200, height: 200)

                Text("Analiz yenileniyor…")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.secondaryLabel)
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
            .background(Color(hex: 0xFF2D55))
            .clipShape(Capsule(style: .continuous))
            .shadow(color: Color(hex: 0xFF2D55).opacity(0.22), radius: 22, x: 0, y: 10)
        }
        .buttonStyle(ProfileInsightPrimaryTapStyle(scale: 0.97))
        .disabled(isRefreshing)
        .opacity(isRefreshing ? 0.55 : 1)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial.opacity(colorScheme == .dark ? 0.9 : 0.92))
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

    var pageBackground: Color {
        switch self {
        case .light: return Color(hex: 0xFAF9FE)
        case .dark: return Color(hex: 0x131315)
        }
    }

    var headerDivider: Color {
        switch self {
        case .light: return Color(hex: 0xE3E2E7)
        case .dark: return Color.white.opacity(0.12)
        }
    }

    var headerIconMuted: Color {
        switch self {
        case .light: return Color(hex: 0x5D3F40)
        case .dark: return Color(hex: 0xE6BCBD).opacity(0.88)
        }
    }

    var secondaryLabel: Color {
        switch self {
        case .light: return Color(hex: 0x5D3F40).opacity(0.85)
        case .dark: return Color(hex: 0xCAB8B9)
        }
    }

    var bannerText: Color {
        switch self {
        case .light: return Color(hex: 0x4A2F30)
        case .dark: return Color(hex: 0xF3E9EA)
        }
    }

    static let bannerFill = Color(hex: 0xFFF4ED)
    static let bannerStroke = Color(hex: 0xFFB86C).opacity(0.55)
    static let errorInk = Color(hex: 0xBA1A1A)
    static let errorContainerFill = Color(hex: 0xFFDAD6)
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
