import SwiftUI
import UIKit

struct CompatibilityResultReasonCard: View {
    let title: String
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .resultGlassCard(cornerRadius: 17, shadowRadius: 10, shadowY: 4)
    }
}

struct CompatibilityResultOngoruCard: View {
    let item: ForecastCard
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(item.tint.opacity(0.12))
                        Image(systemName: item.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(item.tint)
                    }
                    .frame(width: 38, height: 38)

                    Text(item.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                Text(item.badge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(item.badgeBackground)
                    .foregroundStyle(item.badgeForeground)
                    .clipShape(Capsule())
            }

            Text(item.text)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(crHex: 0x3B82F6))
                    Text("İletişim İpucu")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Text(item.tip)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(HarmonyPanelChrome.insetWell(cornerRadius: 12, colorScheme: colorScheme))
        }
        .padding(16)
        .resultGlassCard(cornerRadius: 21, shadowRadius: 13, shadowY: 6)
    }
}

struct CompatibilityResultBuzkiranPromptCard: View {
    let item: BuzkiranCardItem
    let index: Int
    let isCopied: Bool
    let colorScheme: ColorScheme
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(item.strip.opacity(0.5))
                .frame(width: 4)

            ZStack {
                Circle()
                    .fill(item.bubble)
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.strip)
            }
            .frame(width: 30, height: 30)

            Text(item.text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = item.text
                onCopy()
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isCopied ? Color(crHex: 0x1D4ED8) : .secondary)
                    .frame(width: 36, height: 36)
                    .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 36, colorScheme: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .resultGlassCard(cornerRadius: 23, shadowRadius: 10, shadowY: 5)
    }
}
