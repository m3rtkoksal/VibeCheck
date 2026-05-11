import SwiftUI

struct OngoruResultTabContent: View {
    @ObservedObject var vm: CompatibilityAnalysisResultViewModel

    private var ongoruForecastCards: [ForecastCard] {
        vm.forecastItems.map { item in
            let p = CompatibilityResultForecastPalette.style(for: item.risk)
            return ForecastCard(
                title: item.title,
                text: item.text,
                icon: p.icon,
                tint: p.tint,
                badge: item.risk,
                badgeBackground: p.badgeBackground,
                badgeForeground: p.badgeForeground,
                tip: item.tip
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CompatibilityResultForecastProfilesRow(
                    myAvatarUIImage: vm.myAvatarUIImage,
                    partnerLabel: vm.partnerLabel
                )
                .padding(.top, 6)

                VStack(spacing: 10) {
                    ForEach(Array(ongoruForecastCards.enumerated()), id: \.offset) { _, item in
                        CompatibilityResultOngoruCard(item: item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }
}
