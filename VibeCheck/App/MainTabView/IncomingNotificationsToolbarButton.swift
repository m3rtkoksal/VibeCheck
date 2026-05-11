import SwiftUI

/// Ana sekmelerde paylaşılan puan bildirimi çanı (Profil ile aynı görünüm).
struct IncomingNotificationsToolbarButton: View {
    @ObservedObject private var incomingRatings = IncomingCompatibilityRatingsNotifier.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var bellTint: Color {
        colorScheme == .dark ? Color(mtHex: 0x5C8EFF) : Color(mtHex: 0x004BE3)
    }

    var body: some View {
        NavigationLink {
            IncomingCompatibilityRatingsInboxView()
        } label: {
            bellLabel(count: incomingRatings.badgeCount)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            incomingRatings.badgeCount > 0 ?
                "Puan bildirimleri, \(incomingRatings.badgeCount) bekleyen" :
                "Puan bildirimleri"
        )
    }

    private func bellLabel(count: Int) -> some View {
        let circleSize: CGFloat = 40
        // Rozet için yatay alan — çift haneli / 99+ sığsın.
        let labelWidth: CGFloat = count > 9 ? 56 : (count > 0 ? 52 : 44)

        return ZStack {
            Group {
                if reduceTransparency {
                    Circle()
                        .fill(colorScheme == .dark ? Color(mtHex: 0x2A3244) : Color(mtHex: 0xFFFFFF))
                } else {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle()
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.07 : 0.2))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                lineWidth: 1
                            )
                    }
                }
            }
            .frame(width: circleSize, height: circleSize)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                radius: 3,
                x: 0,
                y: 1
            )

            Image(systemName: "bell.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(bellTint)

            if count > 0 {
                VStack {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 11, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, count > 9 ? 5 : 0)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule(style: .continuous).fill(Color(mtHex: 0x2563EB)))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                            .accessibilityHidden(true)
                            // Taşmayı solda tut: sağ kenar clipping’i azalır.
                            .offset(x: -5, y: 1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
            }
        }
        .frame(width: labelWidth, height: 44)
        .contentShape(Rectangle())
    }
}
