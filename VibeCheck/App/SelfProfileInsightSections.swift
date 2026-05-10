import SwiftUI

// MARK: - Gövde tipografisi (özet + maddeler)

private enum CharacterInsightBodyTypography {
    static let font = Font.system(size: 17, weight: .medium)
    static let lineSpacing: CGFloat = 5
}

/// Nazik hatırlatmalar ve özet maddeleri — pembe dolu nokta + asılı girinti.
private struct CharacterInsightPinkBulletLine: View {
    let text: String
    let textColor: Color

    private static let dotDiameter: CGFloat = 6
    /// Nokta sütunu: hizalama + nefes (ikinci referans görsel).
    private static let leadingGutter: CGFloat = 18
    private static let columnTextGap: CGFloat = 14
    /// ~ilk satır cap yüksekliği ile 6 pt nokta hizası
    private static let dotTopPadding: CGFloat = 7

    var body: some View {
        HStack(alignment: .top, spacing: Self.columnTextGap) {
            Circle()
                .fill(CharacterInsightCopy.vibePink)
                .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                .frame(width: Self.leadingGutter, alignment: .leading)
                .padding(.top, Self.dotTopPadding)

            Text(text)
                .font(CharacterInsightBodyTypography.font)
                .foregroundStyle(textColor)
                .lineSpacing(CharacterInsightBodyTypography.lineSpacing)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Model Yardımı

extension AISelfProfileInsight {
    /// Eski kayıtlarda `aboutYou` dolu olabilir; yeni şemada tek `summary`.
    fileprivate var unifiedSummaryMarkdownPlain: String {
        let trimmedSummary =
            summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let bullets =
            aboutYou
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        guard !bullets.isEmpty else {
            return trimmedSummary
        }

        let chunk = bullets.map { "• \($0)" }.joined(separator: "\n")
        if trimmedSummary.isEmpty {
            return chunk
        }
        return trimmedSummary + "\n\n" + chunk
    }

    fileprivate func orderedTraits() -> [AISelfProfileInsight.Trait]? {
        guard let raw = traitBreakdown, !raw.isEmpty else { return nil }

        let order = [
            "introversion",
            "creativity",
            "logic",
            "empathy",
            "ambition",
        ]

        return order.compactMap { key in
            raw.first { $0.id.lowercased() == key }
        }
    }
}

// MARK: - Paylaşılan gövde (Stitch “Karakter Özetin” görünümü; hero yok.)

struct SelfProfileInsightSections: View {
    let insight: AISelfProfileInsight
    var bottomSpacerMin: CGFloat = 32

    /// Stitch `p-lg` — karakter boyutları kartı içi.
    private static let dimensionsCardPadding: CGFloat = 24

    /// `unifiedSummaryMarkdownPlain` içindeki `• …` satırlarını ayırır.
    private static func parseSummaryLeadAndBulletLines(_ raw: String) -> (
        lead: String,
        bullets: [String]
    ) {
        let lines = raw.components(separatedBy: "\n")

        var leadParagraphs: [String] = []
        var bullets: [String] = []
        var currentLeadLines: [String] = []

        func flushLeadParagraph() {
            let trimmedBlock =
                currentLeadLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedBlock.isEmpty {
                leadParagraphs.append(trimmedBlock)
            }
            currentLeadLines.removeAll()
        }

        for line in lines {
            let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
            if trimmedLeading.hasPrefix("•") {
                flushLeadParagraph()
                let body =
                    String(trimmedLeading.dropFirst()).trimmingCharacters(
                        in: .whitespaces
                    )
                if !body.isEmpty {
                    bullets.append(body)
                }
            } else {
                currentLeadLines.append(line)
            }
        }
        flushLeadParagraph()

        let lead =
            leadParagraphs.joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

        return (lead, bullets)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var palette: CharacterInsightPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            if let traits = insight.orderedTraits() {
                traitDimensionsBlock(traits)
            }

            summaryBlock

            remindersBlock
        }
        .padding(.bottom, bottomSpacerMin)
    }

    // MARK: Karakter boyutları

    private func traitDimensionsBlock(_ traits: [AISelfProfileInsight.Trait]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Karakter Boyutları")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.onSurface)

            VStack(spacing: 20) {
                ForEach(traits, id: \.self) { trait in
                    CharacterDimensionRow(
                        trait: trait,
                        title: CharacterInsightCopy.traitDisplayTitle(for: trait.id),
                        fillColor: CharacterInsightCopy.traitBarFill(for: trait.id),
                        palette: palette
                    )
                }
            }
            .padding(.horizontal, SelfProfileInsightSections.dimensionsCardPadding)
            .padding(.vertical, SelfProfileInsightSections.dimensionsCardPadding)
            .modifier(CharacterSoftCard(palette: palette, cornerRadius: 24))
        }
    }

    // MARK: Özet

    private var summaryBlock: some View {
        let parsed =
            Self.parseSummaryLeadAndBulletLines(insight.unifiedSummaryMarkdownPlain)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CharacterInsightCopy.vibePink)

                Text("Özet")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.onSurface)
            }

            if !parsed.lead.isEmpty {
                Text(parsed.lead)
                    .font(CharacterInsightBodyTypography.font)
                    .foregroundStyle(palette.onSurface)
                    .lineSpacing(CharacterInsightBodyTypography.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !parsed.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(parsed.bullets.enumerated()), id: \.offset) {
                        _, item in
                        CharacterInsightPinkBulletLine(
                            text: item,
                            textColor: palette.onSurface.opacity(0.94)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .modifier(CharacterSoftCard(palette: palette, cornerRadius: 24))
    }

    // MARK: Hatırlatmalar

    @ViewBuilder
    private var remindersBlock: some View {
        let lines =
            insight.gentleReminders
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(CharacterInsightCopy.vibePink)

                    Text("Nazik Hatırlatmalar")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(palette.onSurface)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        CharacterInsightPinkBulletLine(
                            text: line,
                            textColor: palette.onSurface.opacity(0.94)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CharacterInsightCopy.errorContainer.opacity(colorScheme == .dark ? 0.14 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        CharacterInsightCopy.errorContainer.opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Boyut satırı

private struct CharacterDimensionRow: View {
    let trait: AISelfProfileInsight.Trait
    let title: String
    let fillColor: Color
    let palette: CharacterInsightPalette

    private var percent: Int {
        min(100, max(0, trait.percent))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.onSurface)

                Spacer(minLength: 8)

                Text("\(percent)%")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(palette.onSurfaceVariant)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.trackFill)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geo.size.width * CGFloat(percent) / 100.0)
                }
            }
            .frame(height: 8)
            .accessibilityLabel("\(title), yüzde \(percent)")
        }
    }
}

// MARK: - Kart / palet

private enum CharacterInsightPalette {
    case light
    case dark

    var pageCompatible: Color {
        switch self {
        case .light: return Color(hex: 0xFAF9FE)
        case .dark: return Color(hex: 0x131315)
        }
    }

    var onSurface: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var onSurfaceVariant: Color {
        switch self {
        case .light: return Color(hex: 0x5D3F40)
        case .dark: return Color(hex: 0xE6BCBD)
        }
    }

    var cardFill: Color {
        switch self {
        case .light: return Color(hex: 0xFFFFFF)
        case .dark: return Color(hex: 0x1E1E23)
        }
    }

    var stroke: Color {
        switch self {
        case .light: return Color(hex: 0xE3E2E7).opacity(0.45)
        case .dark: return Color.white.opacity(0.1)
        }
    }

    var trackFill: Color {
        switch self {
        case .light: return Color(hex: 0xEEEDF3)
        case .dark: return Color(hex: 0x35343A)
        }
    }
}

private enum CharacterInsightCopy {
    static let vibePink = Color(hex: 0xFF2D55)
    static let secondaryContainer = Color(hex: 0x6664E4)
    static let errorContainer = Color(hex: 0xFFDAD6)

    static func traitDisplayTitle(for id: String) -> String {
        switch id.lowercased() {
        case "introversion": return "İçe Dönüklük"
        case "creativity": return "Yaratıcılık"
        case "logic": return "Mantık"
        case "empathy": return "Empati"
        case "ambition": return "Odak & motivasyon"
        default: return id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func traitBarFill(for id: String) -> Color {
        switch id.lowercased() {
        case "introversion": return Color(hex: 0xFF2D55)
        case "creativity": return Color(hex: 0x6664E4)
        case "logic": return Color(hex: 0x00855F)
        case "empathy": return Color(hex: 0xFFB3B5)
        case "ambition": return Color(hex: 0x4C4ACA)
        default: return Color(hex: 0xFF2D55)
        }
    }
}

private struct CharacterSoftCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let palette: CharacterInsightPalette
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.cardFill)
                    .shadow(
                        color: Color.black.opacity(
                            colorScheme == .dark ? 0.32 : 0.04
                        ),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.stroke, lineWidth: 1)
            )
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
