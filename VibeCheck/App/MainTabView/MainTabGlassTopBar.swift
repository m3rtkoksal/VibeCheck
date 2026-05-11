import SwiftUI

// MARK: - Ana sekmeler üst çubuğu (SettingsTabView ile aynı düzen)

enum MainTabGlassTopPalette {
    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color(mtHex: 0xE9E7ED).opacity(0.4)
    }
}

struct MainTabGlassTopBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                leading()

                Spacer(minLength: 0)

                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .default))
                    .tracking(-1)
                    .foregroundStyle(.primary)
                    /// Açık modda beyaz gölge mesh’te leke yapıyordu; koyu kontur + hafif glow.
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.22), radius: 0, x: 0, y: 1)
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08), radius: 2, x: 0, y: 0)
                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.12) : Color.clear, radius: 1, x: 0, y: -0.5)

                Spacer(minLength: 0)

                trailing()
            }
            .padding(.horizontal, 12)
            .frame(height: 64)

            Rectangle()
                .fill(MainTabGlassTopPalette.divider(colorScheme))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .background {
            if reduceTransparency {
                Rectangle().fill(.regularMaterial)
            } else {
                Color.clear
            }
        }
    }
}
