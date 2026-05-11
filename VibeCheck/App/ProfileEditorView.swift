import SwiftUI

/// Profil soruları ve özel not. Kurulum akışında (`setupMode`) tamamlanınca özete geçiş butonu gösterilir;
/// ana uygulama tab’ında sadece düzenleme.
struct ProfileEditorView: View {
    private let categories: [ProfileCategory] = ProfileCategory.allCases
    @State private var refreshToken = UUID()
    @AppStorage("profile.privateNote") private var privateNote = ""
    @State private var selectedCategory: ProfileCategory?
    @State private var showPrivateNote = false
    @State private var showInsightSummary = false
    @State private var reverseQuestionOrder = false
    @Environment(\.colorScheme) private var colorScheme

    var setupMode: Bool
    @Binding var showSummary: Bool

    init(setupMode: Bool = false, showSummary: Binding<Bool> = .constant(false)) {
        self.setupMode = setupMode
        self._showSummary = showSummary
    }

    private var palette: ProfileEditorScreenPalette {
        colorScheme == .dark ? .dark : .light
    }

    private var orderedCategories: [ProfileCategory] {
        reverseQuestionOrder ? categories.reversed() : categories
    }

    var body: some View {
        Group {
            if setupMode {
                profileEditorSetupChrome
            } else {
                profileEditorTabChrome
            }
        }
        .tint(Color(hex: 0x2563EB))
        .navigationDestination(item: $selectedCategory) { category in
            AnswerView(
                category: category,
                onContinue: { current in
                    goToNextQuestion(after: current)
                }
            )
        }
        .navigationDestination(isPresented: $showPrivateNote) {
            PrivateNoteView(note: $privateNote)
        }
        .navigationDestination(isPresented: $showInsightSummary) {
            ProfileCharacterInsightView()
        }
        .safeAreaInset(edge: .bottom) {
            if setupMode && isCompleteProfile {
                Button {
                    showSummary = true
                } label: {
                    Text("Devam")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 14, colorScheme: colorScheme))
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
        }
        .id(refreshToken)
        .onAppear {
            refreshToken = UUID()
        }
    }

    private var profileEditorSetupChrome: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                profileScrollInner
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
        }
        .navigationTitle("Profilini tamamla")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.clear, for: .navigationBar)
    }

    private var profileEditorTabChrome: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                MainTabGlassTopBar(title: "Profil") {
                    IncomingNotificationsToolbarButton()
                } trailing: {
                    Color.clear.frame(width: 44, height: 44)
                }

                ScrollView {
                    profileScrollInner
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color.clear)
            }
        }
        .navigationBarHidden(true)
    }

    private var profileScrollInner: some View {
        VStack(spacing: 20) {
            privateNoteHeroCard

            if !setupMode {
                characterInsightStitchCard
            }

            questionsSectionStitch
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, setupMode && isCompleteProfile ? 108 : 32)
    }

    // MARK: - Vurgu kartı (Karakter özeti + özel not)

    private enum ProfileHighlightCardKind {
        case privateNote
        case characterInsight
    }

    private func profileHighlightCardChrome<Content: View>(
        kind _: ProfileHighlightCardKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        return content()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 22, colorScheme: colorScheme)
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 5)
            }
    }

    // MARK: - Kendim hakkında (özel)

    private var privateNoteHeroCard: some View {
        Button {
            showPrivateNote = true
        } label: {
            profileHighlightCardChrome(kind: .privateNote) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        HStack(spacing: 8) {
                            ZStack {
                                HarmonyPanelChrome.toolbarRoundGlass(
                                    diameter: 32,
                                    colorScheme: colorScheme
                                )
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(palette.privateNoteAccent)
                            }
                            .frame(width: 32, height: 32)

                            Text("Kendim hakkında (özel)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(palette.privateNoteAccent)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 10)

                        ZStack {
                            HarmonyPanelChrome.chevronCueCircle(diameter: 28, colorScheme: colorScheme)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.onSurfaceMuted)
                        }
                        .frame(width: 28, height: 28)
                    }

                    Text(
                        "Bu metin diğer üyelere gösterilmez. "
                            + "Gelişmiş analizde sadece senin için kullanılır."
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.onSurfaceMuted)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ProfileEditorCardTapStyle(scale: 0.98))
    }

    // MARK: - Karakter özetin

    private var characterInsightStitchCard: some View {
        Button {
            showInsightSummary = true
        } label: {
            profileHighlightCardChrome(kind: .characterInsight) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        HStack(spacing: 8) {
                            ZStack {
                                HarmonyPanelChrome.toolbarRoundGlass(
                                    diameter: 32,
                                    colorScheme: colorScheme
                                )
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(palette.primaryBlue)
                            }
                            .frame(width: 32, height: 32)

                            Text("Karakter özetin")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(palette.primaryBlue)
                        }

                        Spacer(minLength: 10)

                        if let badge = insightBadge {
                            Text(badge.title)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(badge.background)
                                .foregroundStyle(badge.foreground)
                                .clipShape(Capsule(style: .continuous))
                        }

                        ZStack {
                            HarmonyPanelChrome.chevronCueCircle(diameter: 28, colorScheme: colorScheme)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.onSurfaceMuted)
                        }
                        .frame(width: 28, height: 28)
                    }

                    Text("AI tabanlı kişilik içgörülerin")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.onSurfaceMuted)
                        .padding(.top, 5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ProfileEditorCardTapStyle(scale: 0.98))
    }

    // MARK: - Soru ve Cevaplar

    private var questionsSectionStitch: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Soru ve Cevaplar")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.onSurface)

                Spacer()

                Button {
                    reverseQuestionOrder.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 40, colorScheme: colorScheme))
                        .accessibilityLabel("Soru sırasını ters çevir")
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)

            VStack(spacing: 12) {
                ForEach(orderedCategories) { category in
                    questionRowCard(for: category)
                }
            }
        }
    }

    private func questionRowCard(for category: ProfileCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.onSurface)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(selectedValue(for: category) ?? "Seç")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.onSurfaceMuted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.chevronMuted)
                    .frame(width: 28, height: 28)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .background(
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 18, colorScheme: colorScheme)
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ProfileEditorCardTapStyle(scale: 0.99))
    }

    private func goToNextQuestion(after current: ProfileCategory) -> Bool {
        guard let currentIndex = categories.firstIndex(of: current) else { return false }
        let nextIndex = categories.index(after: currentIndex)
        guard nextIndex < categories.endIndex else {
            showPrivateNote = true
            return true
        }
        selectedCategory = categories[nextIndex]
        return true
    }

    private var isCompleteProfile: Bool {
        let allChoicesSelected = categories.allSatisfy { selectedValue(for: $0) != nil }
        let noteFilled = !privateNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return allChoicesSelected && noteFilled
    }

    private var insightBadge: (
        title: String,
        foreground: Color,
        background: Color
    )? {
        switch SelfProfileInsightStore.profileTabBadge(isProfileComplete: isCompleteProfile) {
        case .none:
            return nil
        case .missingAnalysis:
            return (
                "Eksik",
                Color.secondary,
                Color(.secondarySystemFill)
            )
        case .needsRefresh:
            return (
                "Güncelle",
                Color.orange,
                Color.orange.opacity(0.14)
            )
        }
    }

    private func selectedValue(for category: ProfileCategory) -> String? {
        let key = "profile.category.\(category.id)"
        let value = UserDefaults.standard.string(forKey: key) ?? ""
        return value.isEmpty ? nil : value
    }

    /// Profil özet ekranı ve sunucu tarafı için `soru başlığı → seçim` sözlüğü.
    static func selectionsDictionary() -> [String: String] {
        var result: [String: String] = [:]
        for category in ProfileCategory.allCases {
            let key = "profile.category.\(category.id)"
            let value = UserDefaults.standard.string(forKey: key) ?? ""
            if !value.isEmpty {
                result[category.title] = value
            }
        }
        return result
    }
}

// MARK: - Palet (Stitch renkleri; Plus Jakarta için sistem yazı tipi kullanılıyor)

private enum ProfileEditorScreenPalette {
    case light
    case dark

    var onSurface: Color {
        switch self {
        case .light: return Color(hex: 0x151C27)
        case .dark: return Color(hex: 0xEBF1FF)
        }
    }

    var onSurfaceMuted: Color {
        switch self {
        case .light: return Color(hex: 0x434655)
        case .dark: return Color(hex: 0xA8B2D0).opacity(0.92)
        }
    }

    var primaryBlue: Color {
        switch self {
        case .light: return Color(hex: 0x004BE3)
        case .dark: return Color(hex: 0x5C8EFF)
        }
    }

    /// Özel not — vurgu (mavi ton)
    var privateNoteAccent: Color {
        switch self {
        case .light: return Color(hex: 0x1D4ED8)
        case .dark: return Color(hex: 0x93C5FD)
        }
    }

    private var themeIsLight: Bool {
        switch self {
        case .light: return true
        case .dark: return false
        }
    }

    var chevronMuted: Color {
        Color(hex: 0x737687).opacity(themeIsLight ? 1.0 : 0.75)
    }
}

private struct ProfileEditorCardTapStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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

#Preview("Setup") {
    NavigationStack {
        ProfileEditorView(setupMode: true, showSummary: .constant(false))
    }
}

#Preview("Tab") {
    NavigationStack {
        ProfileEditorView()
    }
}
