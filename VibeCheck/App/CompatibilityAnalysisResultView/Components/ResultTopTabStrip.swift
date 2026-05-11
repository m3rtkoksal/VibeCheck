import SwiftUI

struct ResultTopTabStrip: View {
    @Binding var selectedTab: ResultTopTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(ResultTopTab.allCases), id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            selectedTab == tab ?
                                (colorScheme == .dark ? Color.white : Color(crHex: 0x2563EB)) :
                                Color(.secondaryLabel)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(crHex: 0x3B82F6).opacity(colorScheme == .dark ? 0.22 : 0.14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color(crHex: 0x3B82F6).opacity(0.35), lineWidth: 1)
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.clear)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Material.thin)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04))
            }
            .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme), radius: 10, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
            )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct CompatibilityResultToolbarTitle: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("VibeCheck")
            .font(.system(size: 20, weight: .heavy, design: .default))
            .tracking(-0.6)
            .foregroundStyle(.primary)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.22),
                radius: 0,
                x: 0,
                y: 1
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08),
                radius: 2,
                x: 0,
                y: 0
            )
            .shadow(
                color: colorScheme == .dark ? Color.white.opacity(0.12) : Color.clear,
                radius: 1,
                x: 0,
                y: -0.5
            )
    }
}
