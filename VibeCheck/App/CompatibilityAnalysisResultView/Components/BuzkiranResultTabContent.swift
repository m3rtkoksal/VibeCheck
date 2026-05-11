import SwiftUI

struct BuzkiranResultTabContent: View {
    @ObservedObject var vm: CompatibilityAnalysisResultViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var buzkiranPromptCards: [BuzkiranCardItem] {
        let palette: [(icon: String, strip: Color, bubble: Color)] = [
            ("bubble.left.and.bubble.right.fill", Color(crHex: 0x2563EB), Color(crHex: 0xEFF6FF)),
            ("music.note", Color(crHex: 0x6664E4), Color(crHex: 0xEEF0FF)),
            ("fork.knife", Color(crHex: 0x00855F), Color(crHex: 0xE7F8F2)),
            ("airplane.departure", Color(crHex: 0xF59E0B), Color(crHex: 0xFFF4DF)),
        ]

        return vm.buzkiranItems.enumerated().map { idx, item in
            let p = palette[idx % palette.count]
            return BuzkiranCardItem(
                text: item.prompt,
                icon: p.icon,
                strip: p.strip,
                bubble: p.bubble
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sohbet Başlatıcılar")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)

                Text("Yapay zeka analizine göre sohbeti başlatmak için en iyi cümleler.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(Array(buzkiranPromptCards.enumerated()), id: \.offset) { idx, card in
                        CompatibilityResultBuzkiranPromptCard(
                            item: card,
                            index: idx,
                            isCopied: vm.copiedBuzkiranIndex == idx,
                            colorScheme: colorScheme,
                            onCopy: {
                                vm.copiedBuzkiranIndex = idx
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }
}
