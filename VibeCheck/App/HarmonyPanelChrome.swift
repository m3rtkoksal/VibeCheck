import SwiftUI

/// Geçmiş / mesh üzerindeki cam panel ve ilgili kontroller — tüm ana sekmelerde aynı dil.
enum HarmonyPanelChrome {
    static func panelBackdrop(cornerRadius: CGFloat, colorScheme: ColorScheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let baseGradient = LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: 0x2A2640).opacity(0.94), Color(hex: 0x15121F).opacity(0.88)]
                : [
                    Color(hex: 0xFFFFFF).opacity(0.62),
                    Color(hex: 0xDDD6FE).opacity(0.45),
                    Color(hex: 0xBAE6FD).opacity(0.4),
                    Color(hex: 0xFFF1F9).opacity(0.55),
                  ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return ZStack {
            shape.fill(baseGradient)
            shape.fill(Material.thin)
            shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.07), lineWidth: 1)
        }
    }

    static func cardShadow(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.42) : Color.black.opacity(0.07)
    }

    /// Gömülü alan (arama, TextField).
    static func insetWell(cornerRadius: CGFloat = 12, colorScheme: ColorScheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.fill(Material.ultraThinMaterial)
            shape.fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.035))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.09), lineWidth: 1))
    }

    /// İkincil çerçeveli düğme (paylaş, rehber).
    static func secondaryTintedButtonBackground(
        cornerRadius: CGFloat = 12,
        colorScheme: ColorScheme,
        tint: Color = Color(hex: 0xFF2D55)
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.fill(Material.ultraThinMaterial)
            shape.fill(tint.opacity(colorScheme == .dark ? 0.13 : 0.09))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(colorScheme == .dark ? 0.48 : 0.4), lineWidth: 1))
    }

    /// Ana pembe CTA — gradient + hafif film + üst kenar highlight.
    static func primaryCTAFill(cornerRadius: CGFloat = 14, colorScheme: ColorScheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color(hex: 0xFF3B6E),
                        Color(hex: 0xE51245),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.fill(Material.ultraThinMaterial.opacity(colorScheme == .dark ? 0.28 : 0.22))
            shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.32), lineWidth: 1)
        }
    }

    /// Navigasyon geri — sıralama ikonundan daha saydam (`thin` yerine `ultraThin`).
    static func toolbarBackGlass(
        diameter: CGFloat,
        colorScheme: ColorScheme,
        reduceTransparency: Bool
    ) -> some View {
        Group {
            if reduceTransparency {
                Circle()
                    .fill(colorScheme == .dark ? Color(hex: 0x2A3244).opacity(0.92) : Color.white.opacity(0.94))
            } else {
                ZStack {
                    Circle().fill(Material.ultraThinMaterial)
                    Circle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.12))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay {
            Circle()
                .strokeBorder(
                    Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    lineWidth: 1
                )
        }
    }

    /// Üst çubuk / sıralama gibi küçük yuvarlak cam kuyular.
    static func toolbarRoundGlass(diameter: CGFloat, colorScheme: ColorScheme) -> some View {
        Circle()
            .fill(Material.thin)
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.08),
                        lineWidth: 1
                    )
            }
    }

    /// Küçük chevron rozeti (kart içi).
    static func chevronCueCircle(diameter: CGFloat = 28, colorScheme: ColorScheme) -> some View {
        ZStack {
            Circle()
                .fill(Material.ultraThinMaterial)
                .frame(width: diameter, height: diameter)
            Circle()
                .strokeBorder(
                    Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.07),
                    lineWidth: 1
                )
                .frame(width: diameter, height: diameter)
        }
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
