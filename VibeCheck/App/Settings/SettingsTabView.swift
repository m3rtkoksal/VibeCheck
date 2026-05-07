import SwiftUI
import FirebaseAuth

struct SettingsTabView: View {
    @AppStorage("auth.isLoggedIn") private var isLoggedIn = true
    @AppStorage("auth.provider") private var providerRawValue = ""
    @AppStorage("auth.userId") private var userId = ""
    /// 0: sistem, 1: açık, 2: koyu
    @AppStorage("app.colorSchemePreference") private var colorSchemePreference = 0

    @State private var showAlert = false
    @State private var alertMessage = ""
    @AppStorage("profile.photoSaved") private var photoSaved = false
    @State private var avatarUIImage: UIImage?

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    profileSection

                    VStack(spacing: 0) {
                        Button {
                            alertMessage = "Abonelik yönetimi henüz bağlanmadı."
                            showAlert = true
                        } label: {
                            settingsRowLabel(
                                icon: "star.fill",
                                iconBackground: Color.accentColor.opacity(0.12),
                                iconForeground: Color.accentColor,
                                title: "Abonelik Yönetimi"
                            )
                        }
                        .buttonStyle(.plain)

                        dividerRow

                        NavigationLink {
                            ThemeSelectionView()
                        } label: {
                            settingsRowLabel(
                                icon: "circle.lefthalf.filled",
                                iconBackground: Color.secondary.opacity(0.12),
                                iconForeground: Color.secondary,
                                title: "Tema Seçimi (Açık/Koyu)",
                                trailingText: themeLabel
                            )
                        }
                        .buttonStyle(.plain)

                        dividerRow

                        Button {
                            alertMessage = "Destek bağlantısı henüz eklenmedi."
                            showAlert = true
                        } label: {
                            settingsRowLabel(
                                icon: "questionmark.circle.fill",
                                iconBackground: Color(hex: 0x00694B, alpha: 0.12),
                                iconForeground: Color(hex: 0x00694B),
                                title: "Yardım ve Destek"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .opacity(0)
                            .frame(height: 8)

                        Button(role: .destructive) {
                            signOut()
                        } label: {
                            settingsRowLabel(
                                icon: "rectangle.portrait.and.arrow.right.fill",
                                iconBackground: Color.red.opacity(0.12),
                                iconForeground: .red,
                                title: "Çıkış Yap",
                                titleColor: .red,
                                showChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    Text(appVersionString)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
                .padding(.top, 88)
            }

            topBar
        }
        .navigationBarHidden(true)
        .alert("Uyarı", isPresented: $showAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var topBar: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .frame(height: 64)
                .overlay(
                    Divider()
                        .opacity(0.35),
                    alignment: .bottom
                )

            HStack {
                Spacer()
                Text("VibeCheck")
                    .font(.system(size: 20, weight: .black, design: .default))
                    .tracking(-0.6)
                    .foregroundStyle(Color(hex: 0xFF2D55))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 64)
        }
    }

    private var profileSection: some View {
        VStack(spacing: 12) {
            avatarView

            NavigationLink {
                SettingsDetailView()
            } label: {
                Text("Profili Düzenle")
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.top, 24)
    }

    private var avatarView: some View {
        let size: CGFloat = 96
        return ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            if let avatarUIImage {
                Image(uiImage: avatarUIImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(profileInitials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().stroke(Color.white, lineWidth: 4)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
        .padding(.bottom, 4)
        .onAppear {
            avatarUIImage = photoSaved ? ProfilePhotoStore.load() : nil
        }
        .onChange(of: photoSaved) { _, _ in
            avatarUIImage = photoSaved ? ProfilePhotoStore.load() : nil
        }
    }

    private var dividerRow: some View {
        Divider()
            .padding(.leading, 16 + 40 + 16)
            .opacity(0.35)
    }

    private func settingsRowLabel(
        icon: String,
        iconBackground: Color,
        iconForeground: Color,
        title: String,
        trailingText: String? = nil,
        titleColor: Color = .primary,
        showChevron: Bool = true
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(iconBackground)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }
            .frame(width: 40, height: 40)

            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(titleColor)

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var themeLabel: String {
        switch colorSchemePreference {
        case 1: return "Açık"
        case 2: return "Koyu"
        default: return "Sistem"
        }
    }

    private var profileName: String {
        let user = Auth.auth().currentUser
        if let name = user?.displayName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return "Alex Mercer"
    }

    private var profileEmail: String {
        let user = Auth.auth().currentUser
        if let email = user?.email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return email
        }
        return "alex.mercer@example.com"
    }

    private var profileInitials: String {
        let parts = profileName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return parts.joined()
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Versiyon \(version) (Build \(build))"
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            // ignore: we still proceed with local logout
        }
        providerRawValue = ""
        userId = ""
        isLoggedIn = false
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

