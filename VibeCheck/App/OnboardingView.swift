import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

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
            onboardingBackground
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 16) {
                        Spacer(minLength: 12)
                        ZStack {
                            Circle()
                                .fill(Color(hex: 0xFF2D55).opacity(0.10))
                                .frame(width: 170, height: 170)
                                .blur(radius: 20)

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(0.9),
                                            Color(hex: 0xFFF4FA),
                                        ],
                                        center: .center,
                                        startRadius: 8,
                                        endRadius: 78
                                    )
                                )
                                .frame(width: 156, height: 156)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: 0xFF2D55).opacity(0.18), lineWidth: 1)
                                )

                            Circle()
                                .stroke(Color(hex: 0xFF2D55).opacity(0.16), lineWidth: 6)
                                .frame(width: 126, height: 126)

                            Image(systemName: page.icon)
                                .font(.system(size: 56, weight: .semibold))
                                .foregroundStyle(Color(hex: 0xFF2D55))
                        }

                        Text(page.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Text(page.subtitle)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 340)
                            .padding(.horizontal, 24)

                        Spacer(minLength: 44)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer(minLength: 0)
                    Button(action: continueTapped) {
                        Text(currentPage == pages.count - 1 ? "Başla" : "Devam Et")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.pink)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
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
        }
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

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xFFF6FB),
                    Color(hex: 0xF8F4FF),
                    Color(hex: 0xFFFFFF),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xFF4D8D, alpha: 0.26),
                            Color(hex: 0xFF4D8D, alpha: 0.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .frame(width: 520, height: 520)
                .offset(x: -150, y: -330)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0x8B5CFF, alpha: 0.18),
                            Color(hex: 0x8B5CFF, alpha: 0.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 480, height: 480)
                .offset(x: 170, y: -260)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xFFB38A, alpha: 0.14),
                            Color(hex: 0xFFB38A, alpha: 0.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: 120, y: 360)
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
