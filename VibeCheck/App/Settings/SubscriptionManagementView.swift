import SwiftUI
import FirebaseAuth

/// Ayarlar > Abonelik — Aurora mesh, gradient plan kartı, Harmony cam Vibe Plus kutuları.
struct SubscriptionManagementView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("subscription.notifyPlusLaunch") private var notifyPlusLaunch = false
    @AppStorage("discoverability.fullName") private var storedFullName = ""
    @AppStorage("profile.photoSaved") private var photoSaved = false

    @State private var notifyFeedback = false
    @State private var avatarUIImage: UIImage?

    private var palette: SubscriptionPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SubscriptionSpacing.xl) {
                profileIdentityStrip

                subtitleBlock

                currentPlanPremiumCard

                vibePlusSection
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SubscriptionSpacing.containerPadding)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.clear)
        .background(
            MeshAuroraBackgroundView()
                .ignoresSafeArea()
        )
        .navigationTitle("Abonelik Yönetimi")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .tint(Color(hex: 0x2563EB))
        .overlay(alignment: .top) {
            if notifyFeedback {
                notifyToast
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var trimmedNickname: String {
        storedFullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Profil fotoğrafı altında yalnızca `discoverability.fullName` doluysa takma ad gösterilir.
    private var profileIdentityStrip: some View {
        VStack(spacing: 0) {
            subscriptionAvatarWithGlow

            if !trimmedNickname.isEmpty {
                Text(trimmedNickname)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(palette.onSurface)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, trimmedNickname.isEmpty ? 0 : 8)
    }

    private var subscriptionAvatarWithGlow: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x3B82F6),
                            Color(red: 1, green: 0.71, blue: 0.76),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.38)
                )
                .frame(width: 152, height: 152)
                .blur(radius: 36)
                .offset(y: 4)

            subscriptionAvatarCore
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: Color.black.opacity(0.11), radius: 22, x: 0, y: 10)
        }
        .padding(.top, 4)
    }

    private var subscriptionAvatarCore: some View {
        let size: CGFloat = 128
        return Group {
            if let avatarUIImage {
                Image(uiImage: avatarUIImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white)
                    .overlay {
                        Text(subscriptionProfileInitials)
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(palette.onSurfaceVariant)
                    }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            avatarUIImage = photoSaved ? ProfilePhotoStore.load() : nil
        }
        .onChange(of: photoSaved) { _, _ in
            avatarUIImage = photoSaved ? ProfilePhotoStore.load() : nil
        }
    }

    private var subscriptionProfileInitials: String {
        if !trimmedNickname.isEmpty {
            let parts = trimmedNickname.split(whereSeparator: { $0.isWhitespace })
            let letters =
                parts
                .prefix(2)
                .map { String($0.prefix(1)).uppercased() }
                .joined()
            return letters.isEmpty ? "?" : letters
        }
        if let e = Auth.auth().currentUser?.email, let c = e.first {
            return String(c).uppercased()
        }
        if let p = Auth.auth().currentUser?.phoneNumber?.filter(\.isNumber), let c = p.last {
            return String(c)
        }
        return "?"
    }

    private var subtitleBlock: some View {
        Text("Hesabının güncel durumunu ve planlarını yönet.")
            .font(.system(size: 17))
            .foregroundStyle(palette.onSurfaceVariant.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 20, colorScheme: colorScheme)
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 4)
            )
    }

    /// `premium-card-bg` + gölgeli gradient kartı
    private var currentPlanPremiumCard: some View {
        ZStack {
            LinearGradient(
                colors: palette.premiumGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 110, y: -140)
                .allowsHitTesting(false)

            Circle()
                .fill(Color.black.opacity(0.1))
                .frame(width: 160, height: 160)
                .blur(radius: 40)
                .offset(x: -100, y: 120)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: SubscriptionSpacing.lg) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: SubscriptionSpacing.xs) {
                        Text("Mevcut Plan")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.white.opacity(0.82))

                        Text("VibeCheck\nÜcretsiz")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(-0.4)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Color(hex: 0x3B82F6))
                    }
                }

                Text("Uygulamanın temel özelliklerine süresiz ve ücretsiz erişim sağlıyorsun.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(SubscriptionSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .padding(SubscriptionSpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(
            color: Color(hex: 0x3B82F6).opacity(colorScheme == .dark ? 0.35 : 0.42),
            radius: 28,
            x: 0,
            y: 14
        )
    }

    private var vibePlusSection: some View {
        VStack(alignment: .leading, spacing: SubscriptionSpacing.md) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(vibePlusHeaderGradient)
                            .frame(width: 40, height: 40)
                            .shadow(color: Color(hex: 0x4C4ACA).opacity(0.35), radius: 8, x: 0, y: 4)

                        Image(systemName: "star.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text("Vibe Plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(palette.onSurface)
                        .tracking(-0.3)
                }
                Spacer()
                Text("Yakında")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(palette.secondaryAccent.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(palette.secondaryAccent.opacity(0.22), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }

            Text("Daha derin içgörüler ve premium bir deneyim için sıraya gir.")
                .font(.system(size: 17))
                .foregroundStyle(palette.onSurfaceVariant.opacity(0.92))
                .padding(.bottom, SubscriptionSpacing.sm)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ],
                spacing: 16
            ) {
                plusGlassCell(
                    icon: "sparkles",
                    title: "Sınırsız AI analizi",
                    iconForeground: palette.secondaryAccent
                )
                plusGlassCell(
                    icon: "doc.text.fill",
                    title: "Detaylı karakter raporları",
                    iconForeground: palette.tertiaryAccent
                )
                plusGlassCell(
                    icon: "xmark.rectangle.fill",
                    title: "Reklamsız deneyim",
                    iconForeground: palette.onSurfaceVariant
                )
                plusGlassCell(
                    icon: "headphones.circle.fill",
                    title: "Öncelikli destek",
                    iconForeground: Color(hex: 0x3B82F6)
                )
            }

            Button {
                notifyPlusLaunch.toggle()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    notifyFeedback = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation { notifyFeedback = false }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 21, weight: .semibold))
                    Text(notifyPlusLaunch ? "Kayıtlısın — bildirimi kapat" : "Çıktığında Haber Ver")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 60)
                .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 16, colorScheme: colorScheme))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14),
                    radius: 12,
                    x: 0,
                    y: 6
                )
            }
            .buttonStyle(ScaleOnPressStyle(scale: 0.98))
        }
        .padding(.top, 8)
    }

    /// Cam panel + içerik `items-start`.
    private func plusGlassCell(
        icon: String,
        title: String,
        iconForeground: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: SubscriptionSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(iconForeground)
                .frame(width: 48, height: 48)
                .background(
                    HarmonyPanelChrome.secondaryTintedButtonBackground(
                        cornerRadius: 12,
                        colorScheme: colorScheme,
                        tint: iconForeground
                    )
                )

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.onSurface)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.88)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 16, colorScheme: colorScheme)
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 12, x: 0, y: 5)
        )
    }

    private var vibePlusHeaderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: 0x4C4ACA),
                Color(red: 0.59, green: 0.45, blue: 0.99),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var notifyToast: some View {
        Text(notifyPlusLaunch ? "Vibe Plus için hatırlatma açık." : "Hatırlatma kapalı.")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color(hex: 0x1A1B1F).opacity(0.92)))
            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
    }
}

private struct ScaleOnPressStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum SubscriptionSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let containerPadding: CGFloat = 20
}

// MARK: - Palet

private enum SubscriptionPalette {
    case light
    case dark

    var onSurface: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var onSurfaceVariant: Color {
        switch self {
        case .light: return Color(hex: 0x475569)
        case .dark: return Color(hex: 0x94A3B8)
        }
    }

    /// Premium kart gradient (mavi tonlar)
    var premiumGradient: [Color] {
        switch self {
        case .light:
            return [
                Color(hex: 0x3B82F6),
                Color(hex: 0x1D4ED8),
            ]
        case .dark:
            return [
                Color(hex: 0x3B82F6).opacity(0.96),
                Color(hex: 0x1E3A8A),
            ]
        }
    }

    var secondaryAccent: Color {
        Color(hex: 0x4C4ACA)
    }

    var tertiaryAccent: Color {
        Color(hex: 0x00694B)
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

#Preview("Açık") {
    NavigationStack {
        SubscriptionManagementView()
    }
    .preferredColorScheme(.light)
}

#Preview("Koyu") {
    NavigationStack {
        SubscriptionManagementView()
    }
    .preferredColorScheme(.dark)
}
