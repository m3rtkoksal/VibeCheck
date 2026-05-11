import SwiftUI
import UIKit

/// Ayarlar > Yardım: Stitch / Material tasarım token’larına yakın yüzeyler; metinler Türkçe.
/// Destek e-posta adresini (`supportEmail`) yayın öncesi doğrula.

struct HelpSupportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

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
            .background(Color.clear)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
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
            }
            ToolbarItem(placement: .principal) {
                helpToolbarTitle
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    searchFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 36, height: 36)
                        .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 36, colorScheme: colorScheme))
                }
                .accessibilityLabel("Aramayı aç")
            }
        }
        .tint(Color(hex: 0xE51245))
    }

    private var helpToolbarTitle: some View {
        let dark = colorScheme == .dark
        return Text("Destek")
            .font(.system(size: 20, weight: .heavy, design: .default))
            .tracking(-0.5)
            .foregroundStyle(Color(hex: 0xE51245))
            .shadow(color: dark ? Color.black.opacity(0.55) : Color.black.opacity(0.22), radius: 0, x: 0, y: 1)
            .shadow(color: dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08), radius: 2, x: 0, y: 0)
            .shadow(color: dark ? Color.white.opacity(0.12) : Color.clear, radius: 1, x: 0, y: -0.5)
    }

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
            HarmonyPanelChrome.insetWell(
                cornerRadius: HelpSupportRadii.twoXL,
                colorScheme: colorScheme
            )
        )
        .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 4)
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
                Image(systemName: topic.systemImageName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF2D55))
                    .frame(width: 40, height: 40)
                    .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 40, colorScheme: colorScheme))
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
                HarmonyPanelChrome.panelBackdrop(
                    cornerRadius: HelpSupportRadii.twoXL,
                    colorScheme: colorScheme
                )
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: 0xE51245).opacity(colorScheme == .dark ? 0.85 : 0.55) : Color.clear,
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
                        HarmonyPanelChrome.panelBackdrop(
                            cornerRadius: HelpSupportRadii.twoXL,
                            colorScheme: colorScheme
                        )
                        .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 12, x: 0, y: 5)
                    )
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
        .tint(Color(hex: 0xE51245))
        .padding(HelpSupportSpacing.md)
        .background(
            HarmonyPanelChrome.panelBackdrop(
                cornerRadius: HelpSupportRadii.twoXL,
                colorScheme: colorScheme
            )
            .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), lineWidth: 1)
        )
        .transaction { txn in txn.animation = .easeInOut(duration: 0.2) }
    }

    // MARK: - İletişim kutusu

    private var contactBanner: some View {
        VStack(spacing: HelpSupportSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color(hex: 0xE51245))
                .frame(width: 56, height: 56)
                .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 56, colorScheme: colorScheme))

            VStack(spacing: HelpSupportSpacing.xs) {
                Text("Hâlâ yardım mı lazım?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.onBackground)

                Text(supportSubtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .multilineTextAlignment(.center)

                if copiedEmailBanner {
                    Text("Destek adresi panoya kopyalandı.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xE51245))
                        .padding(.top, HelpSupportSpacing.xs)
                }
            }

            VStack(spacing: HelpSupportSpacing.sm) {
                Button {
                    openSupportMailComposer()
                } label: {
                    Text("Bize yaz")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minHeight: 50)
                        .frame(maxWidth: .infinity)
                        .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 16, colorScheme: colorScheme))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14), radius: 10, x: 0, y: 4)
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
                        .foregroundStyle(
                            colorScheme == .dark ? Color(hex: 0xFFB3B5) : Color(hex: 0xE51245)
                        )
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Destek adresini panoya kopyala")
            }
        }
        .padding(HelpSupportSpacing.lg)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                HarmonyPanelChrome.panelBackdrop(
                    cornerRadius: HelpSupportRadii.twoXL,
                    colorScheme: colorScheme
                )
                RoundedRectangle(cornerRadius: HelpSupportRadii.twoXL, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0xFF2D55).opacity(colorScheme == .dark ? 0.16 : 0.1),
                                Color(hex: 0x7C3AED).opacity(colorScheme == .dark ? 0.06 : 0.04),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(
                color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme),
                radius: 14,
                x: 0,
                y: 8
            )
        }
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

// MARK: - Metin rolleri (mesh / cam üzerinde)

private enum HelpSupportPalette {
    case light
    case dark

    /// Bölüm başlıkları (on-background)
    var onBackground: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
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
