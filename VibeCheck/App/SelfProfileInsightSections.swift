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
                        palette: palette,
                        colorScheme: colorScheme
                    )
                }
            }
            .padding(.horizontal, SelfProfileInsightSections.dimensionsCardPadding)
            .padding(.vertical, SelfProfileInsightSections.dimensionsCardPadding)
            .modifier(CharacterHarmonyGlassCard(cornerRadius: 24))
        }
    }

    // MARK: Özet

    private var summaryBlock: some View {
        let parsed =
            Self.parseSummaryLeadAndBulletLines(insight.unifiedSummaryMarkdownPlain)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CharacterInsightCopy.vibePink)
                    .frame(width: 40, height: 40)
                    .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 40, colorScheme: colorScheme))

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
        .modifier(CharacterHarmonyGlassCard(cornerRadius: 24))
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CharacterInsightCopy.vibePink)
                        .frame(width: 40, height: 40)
                        .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 40, colorScheme: colorScheme))

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
            .background {
                ZStack {
                    HarmonyPanelChrome.panelBackdrop(cornerRadius: 24, colorScheme: colorScheme)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    CharacterInsightCopy.errorContainer.opacity(
                                        colorScheme == .dark ? 0.2 : 0.32
                                    ),
                                    CharacterInsightCopy.errorContainer.opacity(
                                        colorScheme == .dark ? 0.08 : 0.14
                                    ),
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
                    y: 6
                )
            }
        }
    }
}

// MARK: - Boyut satırı

private struct CharacterDimensionRow: View {
    let trait: AISelfProfileInsight.Trait
    let title: String
    let fillColor: Color
    let palette: CharacterInsightPalette
    let colorScheme: ColorScheme

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
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
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

    var onSurface: Color {
        switch self {
        case .light: return Color(hex: 0x1A1B1F)
        case .dark: return Color(hex: 0xE5E1E4)
        }
    }

    var onSurfaceVariant: Color {
        switch self {
        case .light: return Color(hex: 0x475569)
        case .dark: return Color(hex: 0x94A3B8)
        }
    }
}

private enum CharacterInsightCopy {
    static let vibePink = Color(hex: 0x3B82F6)
    static let secondaryContainer = Color(hex: 0x6664E4)
    static let errorContainer = Color(hex: 0xDBEAFE)

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
        case "introversion": return Color(hex: 0x3B82F6)
        case "creativity": return Color(hex: 0x6664E4)
        case "logic": return Color(hex: 0x00855F)
        case "empathy": return Color(hex: 0x93C5FD)
        case "ambition": return Color(hex: 0x4C4ACA)
        default: return Color(hex: 0x3B82F6)
        }
    }
}

private struct CharacterHarmonyGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                HarmonyPanelChrome.panelBackdrop(cornerRadius: cornerRadius, colorScheme: colorScheme)
                    .shadow(
                        color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme),
                        radius: 14,
                        x: 0,
                        y: 6
                    )
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
