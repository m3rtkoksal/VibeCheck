import SwiftUI

// MARK: - Lottie ile hizalı palet

/// `mesh-gradient.lottie` içindeki `images/image_0.png` sahnesinden (sık kullanılan RGB demetleri) çıkarıldı.
/// Orijinal animasyon düz `#000` zemin + cyan / sıcak pembe / mor lekeler; burada SwiftUI sahnesine uyarlandı.
private enum MeshPaletteFromLottie {
    // Piksel küme ortaları (~0–255)
    private static let _cyan = Color(red: 0 / 255, green: 216 / 255, blue: 234 / 255)
    private static let _cyanNeon = Color(red: 0 / 255, green: 234 / 255, blue: 234 / 255)
    private static let _cyanBlue = Color(red: 0 / 255, green: 156 / 255, blue: 252 / 255)
    private static let _hotMagenta = Color(red: 252 / 255, green: 0 / 255, blue: 72 / 255)
    private static let _rosePulse = Color(red: 246 / 255, green: 5 / 255, blue: 98 / 255)
    private static let _violet = Color(red: 162 / 255, green: 0 / 255, blue: 216 / 255)
    private static let _indigo = Color(red: 121 / 255, green: 42 / 255, blue: 229 / 255)
    private static let _peri = Color(red: 77 / 255, green: 86 / 255, blue: 232 / 255)
    /// Geçiş bölgesi (pembe‑mor ara ton)
    private static let _wineMagenta = Color(red: 205 / 255, green: 41 / 255, blue: 151 / 255)

    static func topFillBlob(dark: Bool) -> [Color] {
        dark ? [_indigo.opacity(0.62), _violet.opacity(0.42), .clear]
            : [_peri.opacity(0.45), Color(red: 160 / 255, green: 110 / 255, blue: 230 / 255).opacity(0.28), .clear]
    }

    static func cyanSideBlob(dark: Bool) -> [Color] {
        dark ? [_cyanBlue.opacity(0.55), _cyan.opacity(0.38), .clear]
            : [Color(red: 60 / 255, green: 170 / 255, blue: 245 / 255).opacity(0.42), .clear]
    }

    static func magentaBlob(dark: Bool) -> [Color] {
        dark ? [_hotMagenta.opacity(0.58), _rosePulse.opacity(0.45), .clear]
            : [Color(red: 255 / 255, green: 58 / 255, blue: 130 / 255).opacity(0.48), .clear]
    }

    static func violetBlob(dark: Bool) -> [Color] {
        dark ? [_violet.opacity(0.62), Color(red: 180 / 255, green: 0 / 255, blue: 200 / 255).opacity(0.4), .clear]
            : [Color(red: 140 / 255, green: 55 / 255, blue: 210 / 255).opacity(0.38), .clear]
    }

    static func cyanCoreBlob(dark: Bool) -> [Color] {
        dark ? [_cyan.opacity(0.58), _cyanNeon.opacity(0.5), .clear]
            : [Color(red: 30 / 255, green: 195 / 255, blue: 220 / 255).opacity(0.4), .clear]
    }

    static func magentaWineBlob(dark: Bool) -> [Color] {
        dark ? [_wineMagenta.opacity(0.5), _peri.opacity(0.35), .clear]
            : [Color(red: 200 / 255, green: 90 / 255, blue: 170 / 255).opacity(0.32), .clear]
    }

    static func cyanHighlightBlob(dark: Bool) -> [Color] {
        dark ? [_cyanNeon.opacity(0.48), _cyanBlue.opacity(0.32), .clear]
            : [Color(red: 120 / 255, green: 210 / 255, blue: 245 / 255).opacity(0.35), .clear]
    }

    /// Koyu: Lottie siyah zemine yakın az mavi gölgeli
    static let darkGradientTop = Color(red: 0.02, green: 0.015, blue: 0.05)
    static let darkGradientBottom = Color(red: 0.05, green: 0.02, blue: 0.09)

    /// Açık: Lottie pastel hattı; sistem kart beyazından ayrılması için hafif mavi‑lavanta
    static let lightGradientTop = Color(red: 214 / 255, green: 232 / 255, blue: 252 / 255)
    static let lightGradientBottom = Color(red: 222 / 255, green: 218 / 255, blue: 246 / 255)
}

/// Jitter / Stitch tarzı yumuşak aurora mesh.
/// `List`/`TabView` içinde `GeometryReader` kökten küçük kalabiliyordu; tam ekran için `frame(.infinity)` + arka planda boyut alınır.
struct MeshAuroraBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                auroraLayer(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { ctx in
                    auroraLayer(time: ctx.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func auroraLayer(time: Double) -> some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            meshStack(at: time, width: w, height: h)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private func meshStack(at t: Double, width w: CGFloat, height h: CGFloat) -> some View {
        let dark = colorScheme == .dark
        /// Hareket daha “okunaklı”: daha hızlı faz + biraz daha geniş offset + blob nefesi
        let τ = CGFloat(t * 3.05)
        let τ2 = CGFloat(t * 0.78)

        func wobble(_ hz: CGFloat, _ phase: CGFloat, _ px: CGFloat) -> CGFloat {
            px * CGFloat(
                sin(Double(τ * hz + phase)) * 0.82 + sin(Double(τ2 * hz * 1.35 + phase * 1.25)) * 0.2
            )
        }

        func breathe(_ phase: Double) -> CGFloat {
            1.0 + CGFloat(0.05 * sin(Double(t) * 2.65 + phase))
        }

        let baseColorTop = dark ? MeshPaletteFromLottie.darkGradientTop : MeshPaletteFromLottie.lightGradientTop
        let baseColorBottom = dark ? MeshPaletteFromLottie.darkGradientBottom : MeshPaletteFromLottie.lightGradientBottom

        let magX = -w * 0.06 + wobble(0.19, 0, w * 0.1)
        let magY = -h * 0.12 + wobble(0.16, 1.7, h * 0.11)
        let purpX = -w * 0.22 + wobble(0.15, 2.4, w * 0.118)
        let purpY = h * 0.52 + wobble(0.17, 0.8, h * 0.125)
        let skyX = w * 0.48 + wobble(0.2, 3.2, w * 0.134)
        let skyY = h * 0.1 + wobble(0.16, 2.1, h * 0.11)

        /// Üst yarı sahneye oturan geniş gök / lavanta (safe area tepeleri için)
        let topFillX = w * 0.45 + wobble(0.17, 4.9, w * 0.104)
        let topFillY = -h * 0.06 + wobble(0.15, 0.4, h * 0.09)
        let topSideX = -w * 0.08 + wobble(0.18, 5.9, w * 0.096)
        let topSideY = h * 0.06 + wobble(0.14, 2.9, h * 0.084)

        let lavX = w * 0.35 + wobble(0.14, 4.0, w * 0.104)
        let lavY = h * 0.42 + wobble(0.15, 1.2, h * 0.11)

        /// Beyaz flare yerine mavi‑lavanta vurgusu (plusLighter ile üstleri yıkamaz)
        let hiX = w * 0.62 + wobble(0.17, 5.5, w * 0.088)
        let hiY = -h * 0.08 + wobble(0.15, 0.3, h * 0.088)

        return ZStack {
            LinearGradient(
                colors: [baseColorTop, baseColorBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            blob(
                center: CGPoint(x: topFillX, y: topFillY),
                colors: MeshPaletteFromLottie.topFillBlob(dark: dark),
                radius: max(w, h) * 0.72 * breathe(0),
                blur: dark ? 58 : 66
            )

            blob(
                center: CGPoint(x: topSideX, y: topSideY),
                colors: MeshPaletteFromLottie.cyanSideBlob(dark: dark),
                radius: max(w, h) * 0.58 * breathe(1.4),
                blur: dark ? 50 : 56
            )

            blob(
                center: CGPoint(x: magX, y: magY),
                colors: MeshPaletteFromLottie.magentaBlob(dark: dark),
                radius: max(w, h) * 0.58 * breathe(2.8),
                blur: dark ? 50 : 56
            )

            blob(
                center: CGPoint(x: purpX, y: purpY),
                colors: MeshPaletteFromLottie.violetBlob(dark: dark),
                radius: max(w, h) * 0.62 * breathe(4.2),
                blur: dark ? 54 : 60
            )

            blob(
                center: CGPoint(x: skyX, y: skyY),
                colors: MeshPaletteFromLottie.cyanCoreBlob(dark: dark),
                radius: max(w, h) * 0.55 * breathe(5.5),
                blur: dark ? 48 : 54
            )

            blob(
                center: CGPoint(x: lavX, y: lavY),
                colors: MeshPaletteFromLottie.magentaWineBlob(dark: dark),
                radius: max(w, h) * 0.5 * breathe(3.1),
                blur: dark ? 52 : 58
            )

            blob(
                center: CGPoint(x: hiX, y: hiY),
                colors: MeshPaletteFromLottie.cyanHighlightBlob(dark: dark),
                radius: max(w, h) * 0.44 * breathe(6.3),
                blur: dark ? 40 : 48
            )
        }
    }

    private func blob(center: CGPoint, colors: [Color], radius: CGFloat, blur: CGFloat) -> some View {
        let capped = colors.count > 5 ? Array(colors.prefix(5)) : colors
        return Circle()
            .fill(
                RadialGradient(
                    colors: capped,
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
            .blur(radius: blur)
            // `plusLighter` + önceki `drawingGroup` açık zeminde beyaza taşabiliyordu
            .blendMode(.normal)
    }
}

#if DEBUG
#Preview("Aurora") {
    MeshAuroraBackgroundView()
        .ignoresSafeArea()
}

#Preview("Aurora dark") {
    MeshAuroraBackgroundView()
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
}
#endif
