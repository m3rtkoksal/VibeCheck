import SwiftUI

struct ResultGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: cornerRadius, colorScheme: colorScheme)
                .shadow(
                    color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
        )
    }
}

/// Uyum özeti — üstte hafif pembe “hero” wash.
struct ResultHeroGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                HarmonyPanelChrome.panelBackdrop(cornerRadius: 22, colorScheme: colorScheme)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(crHex: 0x3B82F6).opacity(colorScheme == .dark ? 0.16 : 0.1),
                                Color(crHex: 0x7C3AED).opacity(colorScheme == .dark ? 0.06 : 0.04),
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
}

extension View {
    func resultGlassCard(cornerRadius: CGFloat = 18, shadowRadius: CGFloat = 11, shadowY: CGFloat = 5) -> some View {
        modifier(ResultGlassCardModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius, shadowY: shadowY))
    }

    func resultHeroGlass() -> some View {
        modifier(ResultHeroGlassModifier())
    }
}
