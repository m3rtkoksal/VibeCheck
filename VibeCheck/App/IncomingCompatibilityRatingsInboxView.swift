import SwiftUI

/// Profil çanından açılan puan bildirimi listesi → karşı puanlamaya gidilir.
struct IncomingCompatibilityRatingsInboxView: View {
    @ObservedObject private var notifier = IncomingCompatibilityRatingsNotifier.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if notifier.pendingRows.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(notifier.pendingRows) { row in
                        NavigationLink {
                            CompatibilityAnalysisResultView(output: row.rateBackOutput)
                        } label: {
                            rowLabel(row)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Puan bildirimi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notifier.markSeenMatchingCurrentInbox(rows: notifier.pendingRows)
        }
        .onChange(of: notifier.pendingRows.map(\.id)) { _, _ in
            notifier.markSeenMatchingCurrentInbox(rows: notifier.pendingRows)
        }
        .task {
            await UserPushTokenSync.requestAuthorizationIfNeeded()
        }
        .background(backgroundGradient.ignoresSafeArea())
    }

    private func rowLabel(_ row: IncomingCompatibilityRatingPendingRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.raterDisplayName)
                .font(.headline)

            Text("Seni \(row.receivedRating.overallScore)% puanladı.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Uyum yüzdesi: %\(row.sharedAI.percent). Sen de karşılık ver.")
                .font(.caption)
                .foregroundStyle(Color(hex: 0xBA0034))
                .padding(.top, 2)

            Text(row.partnerQuery)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Şimdilik bildirimin yok")
                .font(.title3.bold())
            Text(
                "Biri seni puanladığında bildirim alırsın; buradan aynı analiz ile onu da puanlayabilirsin."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                colorScheme == .dark ? Color(hex: 0x12131A) : Color(hex: 0xFFF6F7),
                colorScheme == .dark ? Color(hex: 0x171A24) : Color(hex: 0xF3F6FF),
                colorScheme == .dark ? Color(hex: 0x0D0E14) : Color.white,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
