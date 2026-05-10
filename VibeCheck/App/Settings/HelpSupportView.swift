import SwiftUI
import UIKit

/// Ayarlar > Yardım: Stitch / Material tasarım token’larına yakın yüzeyler; metinler Türkçe.
/// Destek e-posta adresini (`supportEmail`) yayın öncesi doğrula.

struct HelpSupportView: View {
    @Environment(\.colorScheme) private var colorScheme

    @FocusState private var searchFocused: Bool
    @State private var searchText = ""
    @State private var selectedTopic: HelpTopicCategory?
    @State private var copiedEmailBanner = false

    private static var supportEmail: String {
        "destek@mika.technology"
    }

    private var palette: HelpSupportPalette {
        colorScheme == .dark ? .dark : .light
    }

    private var filteredFAQs: [HelpFAQItem] {
        let q = HelpFAQToken.normalize(searchText)
        return HelpFAQItem.all.filter { item in
            let topicOK = selectedTopic.map { item.topics.contains($0) } ?? true
            guard topicOK else { return false }
            guard !q.isEmpty else { return true }
            return item.searchableBlob.contains(q)
        }
    }

    /// Önceki `mailto` kurulumunda `scheme` + `path` birleşimi geçersiz URL üretip Mail’in açılmamasına yol açabiliyordu.
    private static func makeSupportMailURL() -> URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let konu = "VibeCheck destek talebi"
        let gövde =
            """
            Uygulama sürümü: \(version) (yapı \(build))

            Sorunumu veya geri bildirimimi aşağıya yazıyorum:


            """

        guard var components = URLComponents(string: "mailto:\(supportEmail)") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "subject", value: konu),
            URLQueryItem(name: "body", value: gövde),
        ]
        return components.url
    }

    private func openSupportMailComposer() {
        guard let url = Self.makeSupportMailURL() else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HelpSupportSpacing.xl) {
                searchBar

                topicSection

                faqSection

                contactBanner
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, HelpSupportSpacing.containerPadding)
            .padding(.top, HelpSupportSpacing.md)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(palette.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(palette.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Destek")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.navigationTitleAccent)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    searchFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(palette.toolbarIcon)
                }
                .accessibilityLabel("Aramayı aç")
            }
        }
        .tint(palette.navigationTitleAccent)
    }

    // MARK: - Arama

    private var searchBar: some View {
        HStack(spacing: HelpSupportSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(palette.onSurfaceVariant)

            TextField("Nasıl yardımcı olabiliriz?", text: $searchText)
                .focused($searchFocused)
                .font(.system(size: 17))
                .foregroundStyle(palette.onSurface)
        }
        .padding(.leading, HelpSupportSpacing.md + 8)
        .padding(.trailing, HelpSupportSpacing.md)
        .padding(.vertical, HelpSupportSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                .fill(palette.searchFieldBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                .stroke(palette.searchFieldBorder, lineWidth: colorScheme == .dark ? 1 : 0)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.04), radius: 20, x: 0, y: 10)
    }

    // MARK: - Konular (bento grid)

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: HelpSupportSpacing.md) {
            Text("Konular")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.onBackground)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: HelpSupportSpacing.md),
                    GridItem(.flexible(), spacing: HelpSupportSpacing.md),
                ],
                spacing: HelpSupportSpacing.md
            ) {
                ForEach(HelpTopicCategory.allCases, id: \.self) { topic in
                    topicTile(topic)
                }
            }
        }
    }

    private func topicTile(_ topic: HelpTopicCategory) -> some View {
        let isSelected = selectedTopic == topic
        return Button {
            searchText = ""
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTopic = isSelected ? nil : topic
            }
        } label: {
            VStack(alignment: .leading, spacing: HelpSupportSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(palette.topicIconWellFill)
                        .frame(width: 40, height: 40)

                    Image(systemName: topic.systemImageName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.topicIconForeground)
                }
                .padding(.bottom, 2)

                Text(topic.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.onSurface)

                Text(topic.subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(HelpSupportSpacing.md)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 150, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                    .fill(palette.cardSurfaceLowest)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.04), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                    .stroke(
                        isSelected ? palette.selectionStroke : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Sık sorulanlar

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: HelpSupportSpacing.md) {
            Text("Sık sorulan sorular")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.onBackground)

            if filteredFAQs.isEmpty {
                Text("Bu arama veya konuyla eşleşen soru bulunmadı.")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .padding(HelpSupportSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                            .fill(palette.cardSurfaceLowest)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 18, x: 0, y: 8)
            } else {
                VStack(spacing: HelpSupportSpacing.sm) {
                    ForEach(filteredFAQs) { item in
                        faqCard(item)
                    }
                }
            }
        }
    }

    private func faqCard(_ item: HelpFAQItem) -> some View {
        DisclosureGroup {
            Text(item.answer)
                .font(.system(size: 15))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, HelpSupportSpacing.xs)
                .padding(.bottom, HelpSupportSpacing.sm)
                .transition(.opacity)
        } label: {
            Text(item.question)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.onSurface)
                .multilineTextAlignment(.leading)
        }
        .tint(palette.primary)
        .padding(HelpSupportSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                .fill(palette.cardSurfaceLowest)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 18, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                .stroke(palette.outlineSoft, lineWidth: 1)
        )
        .transaction { txn in txn.animation = .easeInOut(duration: 0.2) }
    }

    // MARK: - İletişim kutusu

    private var contactBanner: some View {
        VStack(spacing: HelpSupportSpacing.md) {
            ZStack {
                Circle()
                    .fill(palette.surfaceLowestMuted)
                    .frame(width: 56, height: 56)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(palette.onPrimaryContainer)
            }

            VStack(spacing: HelpSupportSpacing.xs) {
                Text("Hâlâ yardım mı lazım?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.onPrimaryContainer)

                Text(supportSubtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.onPrimaryContainer.opacity(0.92))
                    .multilineTextAlignment(.center)

                if copiedEmailBanner {
                    Text("Destek adresi panoya kopyalandı.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.onPrimaryContainer.opacity(0.95))
                        .padding(.top, HelpSupportSpacing.xs)
                }
            }

            VStack(spacing: HelpSupportSpacing.sm) {
                Button {
                    openSupportMailComposer()
                } label: {
                    Text("Bize yaz")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.contactButtonForeground)
                        .frame(minHeight: 50)
                        .frame(maxWidth: .infinity)
                        .background(palette.contactButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    UIPasteboard.general.string = Self.supportEmail
                    copiedEmailBanner = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        copiedEmailBanner = false
                    }
                } label: {
                    Text(Self.supportEmail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.onPrimaryContainer.opacity(0.9))
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Destek adresini panoya kopyala")
            }
        }
        .padding(HelpSupportSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                .fill(palette.primaryContainer)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
    }

    private var supportSubtitle: String {
        """
        Küçük ekiplerle çalışıyoruz; mesajına uygulama sürümünü ve gerekiyorsa ekran görüntüsü eklersen \
        daha hızlı dönebiliriz.
        """
    }
}

// MARK: - Yerleşim (Stitch “spacing container-padding / xl”)

private enum HelpSupportSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let containerPadding: CGFloat = 20
}

private enum HelpSupportRadii {
    static let twoXL: CGFloat = 24
}

// MARK: - Konular

private enum HelpTopicCategory: String, CaseIterable, Hashable {
    case hesap
    case uyum
    case abonelik
    case teknik

    var title: String {
        switch self {
        case .hesap: return "Hesap"
        case .uyum: return "Uyum analizi"
        case .abonelik: return "Abonelik"
        case .teknik: return "Teknik"
        }
    }

    var subtitle: String {
        switch self {
        case .hesap:
            return "Profil bilgileri, verilerin ve güvenlikle ilgili ayarlar."
        case .uyum:
            return "Sonuçların ve özetteki yüzdelerin anlamı."
        case .abonelik:
            return "Ücretlendirme, yükseltmeler ve özel özellikler."
        case .teknik:
            return "Bağlantı, SMS doğrulama ve performans sorunları."
        }
    }

    var systemImageName: String {
        switch self {
        case .hesap: return "person.crop.circle.fill"
        case .uyum: return "heart.text.square.fill"
        case .abonelik: return "creditcard.fill"
        case .teknik: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Stitch / Material palet (tailwind-config’ten)

private enum HelpSupportPalette {
    case light
    case dark

    // MARK: Light = önceki Stitch açık tema; Dark = `class="dark"` tailwind-config

    /// Üst çubuk zemini (açık: surface, koyu: inverse-surface)
    var surface: Color {
        switch self {
        case .light: return Color(hex: 0xFAF9FE)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var pageBackground: Color {
        switch self {
        case .light: return Color(hex: 0xFAF9FE)
        case .dark: return Color(hex: 0x131315)
        }
    }

    /// Bölüm başlıkları (on-background)
    var onBackground: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    /// Konu / SSS kartları (açık: beyaz; koyu: surface #131315)
    var cardSurfaceLowest: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x131315)
        }
    }

    var surfaceLowestMuted: Color {
        switch self {
        case .light: return Color.white.opacity(0.2)
        case .dark: return Color.white.opacity(0.14)
        }
    }

    var searchFieldBackground: Color {
        switch self {
        case .light: return Color(hex: 0xF2F2F7)
        case .dark: return Color(hex: 0x0E0E10)
        }
    }

    var searchFieldBorder: Color {
        switch self {
        case .light: return Color.clear
        case .dark: return Color(hex: 0x2A2A2C)
        }
    }

    var onSurface: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var onSurfaceVariant: Color {
        switch self {
        case .light: return Color(hex: 0x5D3F40)
        case .dark: return Color(hex: 0xE6BCBD)
        }
    }

    /// Vurgu + DisclosureGroup tint (açık: primary; koyu: primary #ffb3b5)
    var primary: Color {
        switch self {
        case .light: return Color(hex: 0xBA0034)
        case .dark: return Color(hex: 0xFFB3B5)
        }
    }

    /// Üst çubuk başlığı / geri / arama (koyu: inverse-primary)
    var navigationTitleAccent: Color {
        switch self {
        case .light: return Color(hex: 0xBA0034)
        case .dark: return Color(hex: 0xBE0036)
        }
    }

    var toolbarIcon: Color { navigationTitleAccent }

    var topicIconWellFill: Color {
        switch self {
        case .light: return primaryContainer
        case .dark: return Color(hex: 0x0E0E10)
        }
    }

    var topicIconForeground: Color {
        switch self {
        case .light: return onPrimaryContainer
        case .dark: return Color(hex: 0xFF5167)
        }
    }

    var selectionStroke: Color {
        switch self {
        case .light: return Color(hex: 0xBA0034).opacity(0.85)
        case .dark: return Color(hex: 0xFFB3B5)
        }
    }

    var primaryContainer: Color {
        switch self {
        case .light: return Color(hex: 0xE51245)
        case .dark: return Color(hex: 0xFF5167)
        }
    }

    var onPrimaryContainer: Color {
        switch self {
        case .light: return Color(hex: 0xFFFBFF)
        case .dark: return Color(hex: 0x5B0015)
        }
    }

    var contactButtonBackground: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x0E0E10)
        }
    }

    var contactButtonForeground: Color {
        switch self {
        case .light: return Color(hex: 0xBA0034)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var outlineSoft: Color {
        switch self {
        case .light: return Color(hex: 0xE3E2E7).opacity(0.95)
        case .dark: return Color(hex: 0x2A2A2C)
        }
    }
}

private enum HelpFAQToken {
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct HelpFAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
    let topics: Set<HelpTopicCategory>

    /// Arama dizgisi oluşturmak için
    var searchableBlob: String {
        HelpFAQToken.normalize(question + " " + answer)
    }

    static let all: [HelpFAQItem] = [
        HelpFAQItem(
            id: "sms",
            question: "SMS doğrulama kodu gecikiyor veya gelmiyor",
            answer:
                "30–60 saniye bekleyip tekrar dene. Operatör veya servis yoğunluğunda kısa gecikmeler olabilir. "
                    + "Numaranı +90 5xx xxx xx xx biçiminde yazdığından emin ol; mobil veri veya kablosuz bağlantını kontrol et.",
            topics: [.teknik]
        ),
        HelpFAQItem(
            id: "ozet",
            question: "Karakter özetim güncel görünmüyor",
            answer:
                "Profil sorularını veya özel notunu değiştirdiysen, Profil sekmesinde «Karakter Özetin» ekranında "
                    + "«Analizi yenile» ile güncel özeti alabilirsin.",
            topics: [.uyum]
        ),
        HelpFAQItem(
            id: "dogruluk",
            question: "Uyum analizi ne kadar güvenilir?",
            answer:
                "Sonuçlar profil sorularına, özet notlarına ve bulut yapay zekânın yorumlarına dayanır. "
                    + "Çift terapisi veya bilimsel teşhis yerine geçmez; günlük yaşamını ve iletişimini düşündüğün bir araç olarak kullanmak en mantıklısıdır.",
            topics: [.uyum]
        ),
        HelpFAQItem(
            id: "bulunabilirlik",
            question: "Telefon veya X ile nasıl bulunurum?",
            answer:
                "Ayarlar > Profili Düzenle bölümünden telefonunu veya X hesabını doğrulayıp «bulunabileyim» anahtarlarını açabilirsin; "
                    + "doğrulanmayan bilgiler kişisel aramalarda kullanılmaz.",
            topics: [.hesap]
        ),
        HelpFAQItem(
            id: "cikis",
            question: "Hesaptan nasıl çıkarım?",
            answer: "Ayarlar sekmesinin altındaki «Çıkış Yap» ile oturumu kapatabilirsin.",
            topics: [.hesap]
        ),
        HelpFAQItem(
            id: "abonelik",
            question: "Aboneliği veya ödemeleri nasıl yönetirim?",
            answer:
                "Ayarlar > Abonelik Yönetimi’nden mevcut planını ve yakında gelecek Vibe Plus duyurusunu görürsün; "
                    + "Ödeme ve makbuz konularında bize yazarak da yardım alabilirsin.",
            topics: [.abonelik]
        ),
    ]
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

#Preview("Açık") {
    NavigationStack {
        HelpSupportView()
    }
    .preferredColorScheme(.light)
}

#Preview("Koyu") {
    NavigationStack {
        HelpSupportView()
    }
    .preferredColorScheme(.dark)
}
