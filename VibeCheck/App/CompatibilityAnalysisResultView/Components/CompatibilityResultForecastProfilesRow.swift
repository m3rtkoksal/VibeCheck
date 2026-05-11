import SwiftUI
import UIKit

struct CompatibilityResultForecastProfilesRow: View {
    let myAvatarUIImage: UIImage?
    let partnerLabel: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 22) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Material.thin)
                    Group {
                        if let myAvatarUIImage {
                            Image(uiImage: myAvatarUIImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color(crHex: 0x3B82F6))
                        }
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.2 : 0.75),
                                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme).opacity(0.85), radius: 8, x: 0, y: 4)
                .frame(width: 78, height: 78)
                .clipShape(Circle())
                Text("Sen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(crHex: 0x3B82F6).opacity(0.32),
                                Color(crHex: 0x3B82F6).opacity(0.06),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 28
                        )
                    )
                    .frame(width: 46, height: 46)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(crHex: 0x3B82F6))
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
                    .frame(width: 46, height: 46)
            }

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Material.thin)
                    Image(systemName: "person.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(crHex: 0x4C4ACA))
                }
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.2 : 0.75),
                                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme).opacity(0.85), radius: 8, x: 0, y: 4)
                .frame(width: 78, height: 78)
                .clipShape(Circle())
                Text(partnerLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

enum CompatibilityResultForecastPalette {
    static func style(for risk: String) -> (
        icon: String,
        tint: Color,
        badgeBackground: Color,
        badgeForeground: Color
    ) {
        switch risk {
        case "DİKKAT":
            return (
                "creditcard.fill",
                Color(crHex: 0xB45309),
                Color(crHex: 0xB45309),
                .white
            )
        case "ORTA RİSK":
            return (
                "brain.head.profile",
                Color(crHex: 0x4C4ACA),
                Color(crHex: 0x4C4ACA).opacity(0.2),
                Color(crHex: 0x4C4ACA)
            )
        default:
            return (
                "person.3.fill",
                Color(crHex: 0x00694B),
                Color(crHex: 0x00694B).opacity(0.2),
                Color(crHex: 0x00694B)
            )
        }
    }
}
