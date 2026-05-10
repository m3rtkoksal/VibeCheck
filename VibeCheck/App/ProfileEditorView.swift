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
                ScrollView {
                    profileScrollInner
                }
                .scrollDismissesKeyboard(.interactively)
                .background(palette.pageBackground.ignoresSafeArea())
                .navigationTitle("Profilini tamamla")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(palette.pageBackground.opacity(0.94), for: .navigationBar)
            } else {
                ZStack {
                    palette.pageBackground.ignoresSafeArea()
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
                    }
                }
                .navigationBarHidden(true)
            }
        }
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
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0xFF2D55))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        kind: ProfileHighlightCardKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let orbOpacity = colorScheme == .dark ? 0.22 : 0.32
        let fill: Color
        let orb: Color
        let stroke: Color
        switch kind {
        case .privateNote:
            fill = palette.privateNoteCardFill
            orb = palette.privateNoteOrbAccent
            stroke = palette.privateNoteCardStroke
        case .characterInsight:
            fill = palette.characterInsightCardFill
            orb = palette.characterInsightOrbAccent
            stroke = palette.characterInsightCardStroke
        }

        return content()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fill)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(orb.opacity(orbOpacity))
                            .frame(width: 88, height: 88)
                            .blur(radius: 24)
                            .offset(x: 12, y: -28)
                            .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(stroke, lineWidth: 1.5)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05),
                radius: 8,
                x: 0,
                y: 3
            )
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
                                Circle()
                                    .fill(palette.privateNoteIconWell)
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
                            Circle()
                                .fill(palette.chevronBadgeFill)
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
                                Circle()
                                    .fill(palette.characterInsightIconWell)
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
                            Circle()
                                .fill(palette.chevronBadgeFill)
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
                    ZStack {
                        Circle()
                            .fill(palette.questionSortWell)
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(palette.secondaryAccent)
                    }
                    .frame(width: 40, height: 40)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.questionCardFill)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.cardStrokeMuted, lineWidth: 1)
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

    var pageBackground: Color {
        switch self {
        case .light: return Color(hex: 0xF9F9FF)
        case .dark: return Color(hex: 0x13151C)
        }
    }

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

    var secondaryAccent: Color {
        switch self {
        case .light: return Color(hex: 0xB71038)
        case .dark: return Color(hex: 0xFF5A79)
        }
    }

    var cardLowestFill: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x1C2029)
        }
    }

    var characterInsightCardFill: Color {
        switch self {
        case .light: return Color(hex: 0xEFF4FF)
        case .dark: return Color(hex: 0x1A2235)
        }
    }

    var characterInsightOrbAccent: Color {
        switch self {
        case .light: return Color(hex: 0x8EB0FF)
        case .dark: return Color(hex: 0x4A62C9)
        }
    }

    var characterInsightCardStroke: Color {
        switch self {
        case .light: return Color(hex: 0xD6E2FF).opacity(0.8)
        case .dark: return Color.white.opacity(0.085)
        }
    }

    var characterInsightIconWell: Color {
        primaryBlue.opacity(themeIsLight ? 0.16 : 0.28)
    }

    /// Özel not — sıcak şeftali / terracotta
    var privateNoteCardFill: Color {
        switch self {
        case .light: return Color(hex: 0xFFF8F4)
        case .dark: return Color(hex: 0x2A2420)
        }
    }

    var privateNoteOrbAccent: Color {
        switch self {
        case .light: return Color(hex: 0xFFB89A)
        case .dark: return Color(hex: 0x8F5E50)
        }
    }

    var privateNoteCardStroke: Color {
        switch self {
        case .light: return Color(hex: 0xFFDCCD).opacity(0.92)
        case .dark: return Color.white.opacity(0.09)
        }
    }

    var privateNoteAccent: Color {
        switch self {
        case .light: return Color(hex: 0x9A4026)
        case .dark: return Color(hex: 0xE8A896)
        }
    }

    var privateNoteIconWell: Color {
        privateNoteAccent.opacity(themeIsLight ? 0.14 : 0.26)
    }

    private var themeIsLight: Bool {
        switch self {
        case .light: return true
        case .dark: return false
        }
    }

    var questionCardFill: Color {
        cardLowestFill
    }

    var questionSortWell: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x252B3A)
        }
    }

    var cardStrokeMuted: Color {
        switch self {
        case .light: return Color(hex: 0xC3C5D8).opacity(0.55)
        case .dark: return Color.white.opacity(0.1)
        }
    }

    var chevronBadgeFill: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x2A3244)
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
