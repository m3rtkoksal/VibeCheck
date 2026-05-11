import SwiftUI

enum HistoryMetricChipKind {
    case ai
    case myScore
    case received

    func labelTint(_ scheme: ColorScheme) -> Color {
        switch self {
        case .ai:
            return Color(mtHex: scheme == .dark ? 0x93C5FD : 0x2563EB)
        case .myScore:
            return Color(mtHex: scheme == .dark ? 0xC4B5FD : 0x6D28D9)
        case .received:
            return Color(mtHex: scheme == .dark ? 0x67E8F9 : 0x0891B2)
        }
    }

    /// Uyum sonuç ekranındaki donut ile aynı parlaklık.
    func ringProgressStroke(_ scheme: ColorScheme) -> Color {
        switch self {
        case .ai:
            return scheme == .dark ? Color(mtHex: 0x60A5FA) : Color(mtHex: 0x2563EB)
        case .myScore:
            return scheme == .dark ? Color(mtHex: 0xA78BFA) : Color(mtHex: 0x6D28D9)
        case .received:
            return scheme == .dark ? Color(mtHex: 0x22D3EE) : Color(mtHex: 0x0E7490)
        }
    }

    func ringTrackStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }

    func ringCenterFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.26) : Color.white.opacity(0.48)
    }

    func valueTint(_ scheme: ColorScheme) -> Color {
        switch self {
        case .ai:
            return scheme == .dark ? Color(mtHex: 0xE0F2FE) : Color(mtHex: 0x1E40AF)
        case .myScore:
            return scheme == .dark ? Color(mtHex: 0xF3E8FF) : Color(mtHex: 0x5B21B6)
        case .received:
            return scheme == .dark ? Color(mtHex: 0xECFEFF) : Color(mtHex: 0x134E4A)
        }
    }
}

struct HistoryMiniDonutGauge: View {
    let progress: CGFloat
    let lineWidth: CGFloat
    let trackColor: Color
    let progressColor: Color
    let centerFill: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(centerFill)
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

struct HistoryMetricRingCell: View {
    let title: String
    let percent: Int?
    let kind: HistoryMetricChipKind
    let diameter: CGFloat
    let columnWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var progressUnit: CGFloat {
        guard let p = percent else { return 0 }
        return CGFloat(min(100, max(0, p))) / 100
    }

    private var strokeWidth: CGFloat {
        max(7, diameter * 0.132)
    }

    private var percentFontSize: CGFloat {
        max(12, diameter * 0.24)
    }

    private var titleFontSize: CGFloat {
        max(11, diameter * 0.132)
    }

    private var pendingFontSize: CGFloat {
        max(9, diameter * 0.1)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 7) {
            donutCore

            VStack(alignment: .center, spacing: 2) {
                Text(title)
                    .font(.system(size: titleFontSize, weight: .semibold))
                    .foregroundStyle(kind.labelTint(colorScheme).opacity(colorScheme == .dark ? 0.92 : 0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: columnWidth, alignment: .center)

                if percent == nil {
                    Text("Bekleniyor")
                        .font(.system(size: pendingFontSize, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: columnWidth, alignment: .center)
                }
            }
        }
        .frame(width: columnWidth, alignment: .center)
        .padding(.top, 5)
    }

    private var donutCore: some View {
        ZStack(alignment: .center) {
            HistoryMiniDonutGauge(
                progress: progressUnit,
                lineWidth: strokeWidth,
                trackColor: kind.ringTrackStroke(colorScheme),
                progressColor: kind.ringProgressStroke(colorScheme),
                centerFill: kind.ringCenterFill(colorScheme)
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(width: diameter, height: diameter, alignment: .center)

            if let p = percent {
                Text("\(p)%")
                    .font(.system(size: percentFontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(kind.valueTint(colorScheme))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: diameter, height: diameter, alignment: .center)
            } else {
                Image(systemName: "hourglass")
                    .font(.system(size: max(11, diameter * 0.2), weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                    .frame(width: diameter, height: diameter, alignment: .center)
            }
        }
        .frame(width: diameter, height: diameter)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var a11yLabel: String {
        if let p = percent {
            return "\(title), yüzde \(p)"
        }
        return "\(title), henüz yok"
    }
}
