import SwiftUI
import UIKit

/// Profil çanından açılan puan bildirimi listesi → karşı puanlamaya gidilir.
struct IncomingCompatibilityRatingsInboxView: View {
    @ObservedObject private var notifier = IncomingCompatibilityRatingsNotifier.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            MeshAuroraBackgroundView()
                .ignoresSafeArea()

            Group {
                if notifier.pendingRows.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(notifier.pendingRows) { row in
                                NavigationLink {
                                    CompatibilityAnalysisResultView(output: row.rateBackOutput)
                                } label: {
                                    inboxGlassRow(row)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listSectionSpacing(12)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Puan bildirimi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .onAppear {
            notifier.markSeenMatchingCurrentInbox(rows: notifier.pendingRows)
        }
        .onChange(of: notifier.pendingRows.map(\.id)) { _, _ in
            notifier.markSeenMatchingCurrentInbox(rows: notifier.pendingRows)
        }
        .task {
            await UserPushTokenSync.requestAuthorizationIfNeeded()
        }
    }

    private func inboxGlassRow(_ row: IncomingCompatibilityRatingPendingRow) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0x3B82F6).opacity(colorScheme == .dark ? 0.24 : 0.16),
                                    Color(hex: 0x7C3AED).opacity(colorScheme == .dark ? 0.14 : 0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: colorScheme == .dark ? 0x93C5FD : 0x2563EB))
                }
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.raterDisplayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Seni puanladı")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Text("\(row.receivedRating.overallScore)%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x3B82F6))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Material.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08), lineWidth: 1)
                            }
                    )
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2563EB))
                    Text("Ortak uyum \(row.sharedAI.percent)%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text("Sen de aynı analizden karşılık verebilirsin.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HarmonyPanelChrome.insetWell(cornerRadius: 12, colorScheme: colorScheme))

            Text(row.partnerQuery)
                .font(.caption.monospaced())
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .lineLimit(1)
        }
        .padding(16)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 22, colorScheme: colorScheme)
                .shadow(
                    color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme),
                    radius: 14,
                    x: 0,
                    y: 6
                )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x3B82F6).opacity(colorScheme == .dark ? 0.22 : 0.12),
                                Color(hex: 0x7C3AED).opacity(colorScheme == .dark ? 0.12 : 0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x3B82F6), Color(hex: 0x6366F1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4), lineWidth: 1)
            )

            VStack(spacing: 10) {
                Text("Şimdilik bildirimin yok")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(
                    "Biri seni puanladığında bildirim alırsın; buradan aynı analiz ile onu da puanlayabilirsin."
                )
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            HarmonyPanelChrome.panelBackdrop(cornerRadius: 26, colorScheme: colorScheme)
                .shadow(
                    color: HarmonyPanelChrome.cardShadow(colorScheme: colorScheme),
                    radius: 18,
                    x: 0,
                    y: 10
                )
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
