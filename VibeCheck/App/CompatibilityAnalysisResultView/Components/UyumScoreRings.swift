import SwiftUI

// MARK: - Uyum: yan yana skor halkaları

enum UyumScoreRingKind {
    case ai
    case myScore
    case received

    /// Koyu arka planda silik kalmaması için dark’ta daha açık / güçlü tonlar.
    func progressStroke(_ scheme: ColorScheme) -> Color {
        switch self {
        case .ai:
            return scheme == .dark ? Color(crHex: 0x60A5FA) : Color(crHex: 0x2563EB)
        case .myScore:
            return scheme == .dark ? Color(crHex: 0xA78BFA) : Color(crHex: 0x6D28D9)
        case .received:
            return scheme == .dark ? Color(crHex: 0x22D3EE) : Color(crHex: 0x0E7490)
        }
    }

    /// Boş kısım: gradient’te kaybolmaması için koyu modda nötr açık halka.
    func trackStroke(_ scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color.white.opacity(0.22)
        }
        return Color.black.opacity(0.08)
    }

    func centerValueColor(_ scheme: ColorScheme) -> Color {
        switch self {
        case .ai:
            return scheme == .dark ? Color(crHex: 0xE0F2FE) : Color(crHex: 0x1E40AF)
        case .myScore:
            return scheme == .dark ? Color(crHex: 0xF3E8FF) : Color(crHex: 0x5B21B6)
        case .received:
            return scheme == .dark ? Color(crHex: 0xECFEFF) : Color(crHex: 0x134E4A)
        }
    }
}

struct UyumScoreRingItem: Identifiable {
    let id: String
    let title: String
    let percent: Int
    let kind: UyumScoreRingKind
}

struct UyumDonutGauge: View {
    var progress: CGFloat
    var lineWidth: CGFloat
    var trackColor: Color
    var progressColor: Color

    @Environment(\.colorScheme) private var colorScheme

    private var gaugeBackgroundFill: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.32)
            : Color.white.opacity(0.55)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gaugeBackgroundFill)
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: progressColor.opacity(colorScheme == .dark ? 0.55 : 0.35),
                    radius: colorScheme == .dark ? 5 : 3,
                    x: 0,
                    y: 0
                )
        }
    }
}

struct UyumScoreRingCell: View {
    let item: UyumScoreRingItem
    let diameter: CGFloat
    let percentFontSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animatedProgress: CGFloat = 0

    private var progressUnit: CGFloat {
        CGFloat(min(100, max(0, item.percent))) / 100
    }

    private var strokeW: CGFloat {
        max(7.5, diameter * 0.112)
    }

    private static let fillAnimation = Animation.easeOut(duration: 0.95)

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                UyumDonutGauge(
                    progress: animatedProgress,
                    lineWidth: strokeW,
                    trackColor: item.kind.trackStroke(colorScheme),
                    progressColor: item.kind.progressStroke(colorScheme)
                )
                .frame(width: diameter, height: diameter)

                Text("\(item.percent)%")
                    .font(.system(size: percentFontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(item.kind.centerValueColor(colorScheme))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.title), yüzde \(item.percent)")

            Text(item.title)
                .font(.system(size: max(14, min(16, diameter * 0.15)), weight: .semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            playFillAnimation(to: progressUnit)
        }
        .onChange(of: item.percent) { _, newValue in
            let u = CGFloat(min(100, max(0, newValue))) / 100
            playFillAnimation(to: u)
        }
    }

    private func playFillAnimation(to target: CGFloat) {
        if reduceMotion {
            animatedProgress = target
            return
        }
        animatedProgress = 0
        withAnimation(Self.fillAnimation) {
            animatedProgress = target
        }
    }
}
