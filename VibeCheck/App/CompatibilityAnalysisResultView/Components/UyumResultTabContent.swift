import SwiftUI

struct UyumResultTabContent: View {
    @ObservedObject var vm: CompatibilityAnalysisResultViewModel

    private var uyumScoreRingItems: [UyumScoreRingItem] {
        var items: [UyumScoreRingItem] = [
            UyumScoreRingItem(id: "ai", title: "AI Uyum", percent: vm.output.ai.percent, kind: .ai),
        ]
        if let p = vm.resolvedMyOverallScore {
            items.append(
                UyumScoreRingItem(id: "my", title: "Senin Puanın", percent: p, kind: .myScore)
            )
        }
        if let r = vm.receivedRating {
            items.append(
                UyumScoreRingItem(id: "recv", title: "Sana Verilen", percent: r.overallScore, kind: .received)
            )
        }
        return items
    }

    private func ringDiameter(forCount n: Int) -> CGFloat {
        switch n {
        case 1: return 118
        case 2: return 100
        default: return 84
        }
    }

    private func ringPercentFontSize(forCount n: Int) -> CGFloat {
        switch n {
        case 1: return 28
        case 2: return 24
        default: return 20
        }
    }

    private var uyumScoreRingsRow: some View {
        let items = uyumScoreRingItems
        let n = max(1, items.count)
        let spacing: CGFloat = n == 3 ? 8 : 12
        return HStack(alignment: .top, spacing: spacing) {
            ForEach(items) { item in
                UyumScoreRingCell(
                    item: item,
                    diameter: ringDiameter(forCount: items.count),
                    percentFontSize: ringPercentFontSize(forCount: items.count)
                )
            }
        }
        .padding(.vertical, 6)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Uyum Sonucu")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)

                uyumScoreRingsRow

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color(crHex: 0x3B82F6))
                        Text("AI Özeti")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(vm.output.ai.summary)
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .resultHeroGlass()

                Text("Neden Uyumlusunuz?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    ForEach(Array(vm.reasonItems.enumerated()), id: \.offset) { idx, item in
                        CompatibilityResultReasonCard(
                            title: item.title,
                            text: item.text,
                            icon: idx == 0 ? "heart.fill" : "bubble.left.and.bubble.right.fill",
                            tint: idx == 0 ? Color(crHex: 0x3B82F6) : Color(crHex: 0x2563EB)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }
}
