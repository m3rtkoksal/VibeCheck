import SwiftUI
import FirebaseAuth

struct SettingsTabView: View {
    @AppStorage("auth.isLoggedIn") private var isLoggedIn = true
    @AppStorage("auth.provider") private var providerRawValue = ""
    @AppStorage("auth.userId") private var userId = ""
    @AppStorage("app.colorSchemePreference") private var colorSchemePreference = 0
    @AppStorage("discoverability.fullName") private var storedFullName = ""
    @AppStorage("profile.photoSaved") private var photoSaved = false

    @Environment(\.colorScheme) private var colorScheme

    @State private var avatarUIImage: UIImage?
    @State private var versionMenuPresented = false

    private var palette: SettingsScreenPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ZStack {
            palette.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                glassTopBar

                ScrollView {
                    VStack(spacing: 0) {
                        profileSection

                        settingsCardStack

                        versionFooter
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, SettingsScreenMetrics.containerPadding)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .alert(appVersionCompact, isPresented: $versionMenuPresented) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(bundleVersionDetail)
        }
    }

    // MARK: - Üst çubuk

    private var glassTopBar: some View {
        MainTabGlassTopBar(title: "VibeCheck") {
            IncomingNotificationsToolbarButton()
        } trailing: {
            Menu {
                Button {
                    versionMenuPresented = true
                } label: {
                    Label(appVersionCompact, systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(palette.topBarSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Profil

    private var trimmedNickname: String {
        storedFullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var profileSection: some View {
        VStack(spacing: 0) {
            avatarWithGlow

            if !trimmedNickname.isEmpty {
                Text(trimmedNickname)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            if let subtitle = profileSubtitleLine {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.onSurfaceMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, trimmedNickname.isEmpty ? 8 : 4)
            }

            NavigationLink {
                SettingsDetailView()
            } label: {
                Text("Profili Düzenle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onBackground)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(palette.editButtonCapsuleFill)
                    )
            }
            .buttonStyle(SettingsCardPressStyle(scale: 0.96))
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    private var avatarWithGlow: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xFF2D55),
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

            avatarCore
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: Color.black.opacity(0.11), radius: 22, x: 0, y: 10)
        }
        .padding(.bottom, 4)
        .padding(.top, 8)
    }

    private var avatarCore: some View {
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
                        Text(profileInitialsDerived)
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(palette.onSurfaceMuted)
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

    private var profileInitialsDerived: String {
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

    private var profileSubtitleLine: String? {
        let user = Auth.auth().currentUser
        if let email = user?.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        if let phone = user?.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            return phone
        }
        return nil
    }

    // MARK: - Liste kartları

    private var settingsCardStack: some View {
        VStack(spacing: 16) {
            NavigationLink {
                SubscriptionManagementView()
            } label: {
                settingsNavigationCard(
                    symbol: "star.fill",
                    symbolPointSize: 26,
                    title: "Abonelik Yönetimi",
                    trailing: .chevronOnly
                )
            }
            .buttonStyle(SettingsCardPressStyle(scale: 0.98))

            NavigationLink {
                ThemeSelectionView()
            } label: {
                settingsNavigationCard(
                    symbol: "circle.lefthalf.filled",
                    symbolPointSize: 26,
                    title: "Tema Seçimi",
                    trailing: .subtitleAndChevron(themeLabel)
                )
            }
            .buttonStyle(SettingsCardPressStyle(scale: 0.98))

            NavigationLink {
                HelpSupportView()
            } label: {
                settingsNavigationCard(
                    symbol: "questionmark.circle.fill",
                    symbolPointSize: 26,
                    title: "Yardım ve Destek",
                    trailing: .chevronOnly
                )
            }
            .buttonStyle(SettingsCardPressStyle(scale: 0.98))

            Button(role: .destructive) {
                signOut()
            } label: {
                signOutCard
            }
            .buttonStyle(SettingsCardPressStyle(scale: 0.98))
            .padding(.top, 8)
        }
    }

    private enum TrailingAccessory {
        case chevronOnly
        case subtitleAndChevron(String)
    }

    private func settingsNavigationCard(
        symbol: String,
        symbolPointSize: CGFloat,
        title: String,
        trailing: TrailingAccessory
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: symbolPointSize, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF2D55))
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: 0xFF2D55).opacity(colorScheme == .dark ? 0.18 : 0.11))
                )

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch trailing {
            case .chevronOnly:
                chevronBadge
            case .subtitleAndChevron(let sub):
                HStack(spacing: 12) {
                    Text(sub)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.onSurfaceMuted)
                    chevronBadge
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.cardStroke, lineWidth: 1)
        )
        .foregroundStyle(Color.primary)
    }

    private var chevronBadge: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(palette.onSurfaceMuted)
            .frame(width: 32, height: 32)
            .background(Circle().fill(palette.iconWellFill))
    }

    private var signOutCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color(hex: 0xBA1A1A))
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: 0xFFDAD6).opacity(colorScheme == .dark ? 0.35 : 0.62))
                )

            Text("Çıkış Yap")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(hex: 0xBA1A1A))

            Spacer(minLength: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: 0xFFDAD6).opacity(colorScheme == .dark ? 0.45 : 0.85), lineWidth: 1)
        )
        .foregroundStyle(Color.primary)
    }

    private var versionFooter: some View {
        Text(appVersionCompact)
            .font(.system(size: 12, weight: .semibold))
            .tracking(2.8)
            .textCase(.uppercase)
            .foregroundStyle(palette.onSurfaceMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 44)
            .padding(.bottom, 28)
    }

    private var themeLabel: String {
        switch colorSchemePreference {
        case 1: return "Açık"
        case 2: return "Koyu"
        default: return "Sistem"
        }
    }

    private var appVersionCompact: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Versiyon \(version)"
    }

    private var bundleVersionDetail: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Yapı \(build)"
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {}
        providerRawValue = ""
        userId = ""
        isLoggedIn = false
    }
}

// MARK: - Metrikler

private enum SettingsScreenMetrics {
    static let containerPadding: CGFloat = 20
}

// MARK: - Palette

private enum SettingsScreenPalette {
    case light
    case dark

    var pageBackground: Color {
        switch self {
        case .light: return Color(hex: 0xFAF9FE)
        case .dark: return Color(hex: 0x131315)
        }
    }

    var topBarDivider: Color {
        switch self {
        case .light: return Color(hex: 0xE9E7ED)
        case .dark: return Color.white.opacity(0.12)
        }
    }

    var topBarSecondary: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var onBackground: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var onSurfaceMuted: Color {
        switch self {
        case .light: return Color(hex: 0x5D3F40)
        case .dark: return Color(hex: 0xCAB8B9)
        }
    }

    var cardFill: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x1E1E23)
        }
    }

    var cardStroke: Color {
        switch self {
        case .light: return Color(hex: 0xF4F3F8)
        case .dark: return Color.white.opacity(0.08)
        }
    }

    var iconWellFill: Color {
        switch self {
        case .light: return Color(hex: 0xF4F3F8)
        case .dark: return Color(hex: 0x2A2A30)
        }
    }

    var editButtonCapsuleFill: Color {
        switch self {
        case .light: return Color(hex: 0xE3E2E7)
        case .dark: return Color(hex: 0x35343A)
        }
    }
}

// MARK: - Basınç efekti

private struct SettingsCardPressStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.17), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        SettingsTabView()
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
