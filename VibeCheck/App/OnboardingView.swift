import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @Environment(\.colorScheme) private var colorScheme

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "VibeCheck'e Hoş Geldin",
            subtitle: "İlk buluşmadan önce daha net bir resim gör.",
            icon: "heart.text.square.fill"
        ),
        OnboardingPage(
            title: "5 Kilit Soru",
            subtitle: "Karakterini yormadan çıkaran 5 kısa soru: iletişim, sınır, yakınlık ve güven dinamikleri.",
            icon: "slider.horizontal.3"
        ),
        OnboardingPage(
            title: "Vibe Code + AI Notu",
            subtitle: "Hazır prompt ile kişilik notunu ekle, kodunu paylaş, güçlü alanlar ve dikkat noktalarını gör.",
            icon: "person.2.wave.2.fill"
        )
    ]

    var body: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    onboardingSlide(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .safeAreaInset(edge: .bottom) {
                onboardingBottomBar
            }
        }
        .tint(Color(hex: 0x2563EB))
    }

    private func onboardingSlide(page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            onboardingHeroIcon(systemName: page.icon)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .shadow(color: onboardingTitleShadowOuter, radius: 0, x: 0, y: 1)
                    .shadow(color: onboardingTitleShadowMid, radius: 3, x: 0, y: 1)

                Text(page.subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 24, colorScheme: colorScheme)
                    .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 6)
            )
            .padding(.horizontal, 24)

            Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func onboardingHeroIcon(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x3B82F6).opacity(colorScheme == .dark ? 0.14 : 0.1))
                .frame(width: 180, height: 180)
                .blur(radius: 28)

            ZStack {
                Circle()
                    .fill(Material.thin)
                    .frame(width: 132, height: 132)

                Circle()
                    .strokeBorder(
                        Color(hex: 0x2563EB).opacity(colorScheme == .dark ? 0.42 : 0.28),
                        lineWidth: 2
                    )
                    .frame(width: 132, height: 132)

                Image(systemName: systemName)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3B82F6))
            }
            .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 14, x: 0, y: 8)
        }
    }

    private var onboardingBottomBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: continueTapped) {
                Text(currentPage == pages.count - 1 ? "Başla" : "Devam Et")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(Color.white)
                    .background(HarmonyPanelChrome.primaryCTAFill(cornerRadius: 14, colorScheme: colorScheme))
                    .shadow(color: onboardingCtaShadow, radius: 12, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 360)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var onboardingTitleShadowOuter: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.12)
    }

    private var onboardingTitleShadowMid: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.05)
    }

    private var onboardingCtaShadow: Color {
        Color.black.opacity(colorScheme == .dark ? 0.4 : 0.14)
    }

    private func continueTapped() {
        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            hasCompletedOnboarding = true
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
