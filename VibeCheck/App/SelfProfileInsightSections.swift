import SwiftUI
import Charts

/// Kişisel karakter analizi metin blokları (giriş akışı ve Profil detayı ortak).
struct SelfProfileInsightSections: View {
    let insight: AISelfProfileInsight

    var body: some View {
        if let traitBreakdown = insight.traitBreakdown, !traitBreakdown.isEmpty {
            Section {
                TraitOverviewChart(traits: traitBreakdown)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)

                ForEach(traitBreakdown, id: \.self) { trait in
                    TraitCard(trait: trait)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text("Karakter Dağılımı")
            }
        }

        Section {
            InsightTextCard(
                text: insight.summary
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowBackground(Color.clear)
        } header: {
            Text("Özet")
        }

        if !insight.aboutYou.isEmpty {
            Section {
                InsightListCard(
                    lines: insight.aboutYou
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowBackground(Color.clear)
            } header: {
                Text("Sen hakkında")
            }
        }

        Section {
            InsightTextCard(
                text: insight.relationshipStyle
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowBackground(Color.clear)
        } header: {
            Text("İlişki tarzına dair")
        }

        if !insight.gentleReminders.isEmpty {
            Section {
                InsightListCard(
                    lines: insight.gentleReminders
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowBackground(Color.clear)
            } header: {
                Text("Nazik hatırlatmalar")
            }
        }
    }
}

private struct InsightTextCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
        }
        .modifier(InsightCardContainer())
    }
}

private struct InsightListCard: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)

                    Text(line)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
            }
        }
        .modifier(InsightCardContainer())
    }
}

private struct InsightCardContainer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
            )
    }
}

private struct TraitCard: View {
    let trait: AISelfProfileInsight.Trait

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(trait.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(clampedPercent)%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                TraitPercentBar(percent: clampedPercent, tint: iconColor)

                Text(trait.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )
    }

    private var clampedPercent: Int {
        min(100, max(0, trait.percent))
    }

    private var iconName: String {
        switch trait.id.lowercased() {
        case "introversion": return "person.fill"
        case "creativity": return "paintpalette.fill"
        case "logic": return "point.3.connected.trianglepath.dotted"
        case "empathy": return "heart.fill"
        case "ambition": return "flag.fill"
        default: return "sparkles"
        }
    }

    private var iconColor: Color {
        traitColor(for: trait.id)
    }
}

private struct TraitPercentBar: View {
    let percent: Int
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(clampedPercent) / 100.0)
            }
        }
        .frame(height: 6)
    }

    private var clampedPercent: Int {
        min(100, max(0, percent))
    }
}

private struct TraitOverviewChart: View {
    let traits: [AISelfProfileInsight.Trait]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Temel Boyutlar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Chart(traits, id: \.id) { trait in
                BarMark(
                    x: .value("Trait", shortLabel(for: trait)),
                    y: .value("Yüzde", clampedPercent(for: trait))
                )
                .foregroundStyle(traitColor(for: trait.id))
                .annotation(position: .top, spacing: 2) {
                    Text("\(clampedPercent(for: trait))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )
    }

    private func clampedPercent(for trait: AISelfProfileInsight.Trait) -> Int {
        min(100, max(0, trait.percent))
    }

    private func shortLabel(for trait: AISelfProfileInsight.Trait) -> String {
        switch trait.id.lowercased() {
        case "introversion": return "Intro"
        case "creativity": return "Creat."
        case "logic": return "Logic"
        case "empathy": return "Empathy"
        case "ambition": return "Ambit."
        default: return trait.title
        }
    }
}

private func traitColor(for id: String) -> Color {
    switch id.lowercased() {
    case "introversion": return Color(hex: 0x6D28D9) // purple
    case "creativity": return Color(hex: 0xDB2777) // pink
    case "logic": return Color(hex: 0x2563EB) // blue
    case "empathy": return Color(hex: 0x16A34A) // green
    case "ambition": return Color(hex: 0xF59E0B) // amber
    default: return Color(hex: 0xFF2D55)
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
