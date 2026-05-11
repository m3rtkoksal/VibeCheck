import SwiftUI
import UIKit
import FirebaseFirestore

struct CompatibilityHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var items: [CompatibilityHistoryItem] = CompatibilityHistoryStore.load()
    @State private var visibleCount = 8
    @State private var partnerPhotoURLs: [UUID: String] = [:]
    @State private var partnerDisplayNames: [UUID: String] = [:]
    @State private var sortOption: HistorySortOption = .latest
    @State private var historyDetailRoute: HistoryDetailRoute?

    var body: some View {
        VStack(spacing: 0) {
            MainTabGlassTopBar(title: "Geçmiş") {
                IncomingNotificationsToolbarButton()
            } trailing: {
                Color.clear.frame(width: 44, height: 44)
            }

            List {
                    Section {
                        summaryInsights
                            .listRowInsets(EdgeInsets(top: 14, leading: 18, bottom: 8, trailing: 18))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Section {
                        sonAnalizlerHeaderRow
                            .listRowInsets(
                                EdgeInsets(top: 0, leading: 18, bottom: 10, trailing: 18)
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if items.isEmpty {
                        Section {
                            emptyStateCard
                                .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 120, trailing: 18))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        Section {
                            ForEach(displayedHistoryItems) { item in
                                Button {
                                    historyDetailRoute = .analysis(item.id)
                                } label: {
                                    historyCard(item: item, showsAccessoryChevron: true)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        deleteHistoryItem(item)
                                    } label: {
                                        Label("Sil", systemImage: "trash.fill")
                                    }
                                    .tint(Color(mtHex: 0xB45309))
                                }
                                .contextMenu {
                                    Button {
                                        deleteHistoryItem(item)
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        if visibleCount < sortedItems.count {
                            Section {
                                loadMoreHistoryRow
                                    .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 120, trailing: 18))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                .listSectionSpacing(20)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $historyDetailRoute) { route in
            switch route {
            case let .analysis(id):
                if let item = items.first(where: { $0.id == id }) {
                    CompatibilityAnalysisResultView(
                        output: AIOnlyAnalysisOutput(
                            id: item.id,
                            partnerQuery: item.partnerQuery,
                            ai: item.ai,
                            historyId: item.id,
                            myRating: item.myRating,
                            receivedRating: item.receivedRating
                        )
                    )
                } else {
                    Text("Kayıt bulunamadı")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            reloadHistory()
            Task { await preloadPartnerPhotos() }
            syncReceivedRatingsFromCloud()
        }
        .onReceive(NotificationCenter.default.publisher(for: CompatibilityHistoryStore.didUpdateNotification)) { _ in
            reloadHistory()
            Task { await preloadPartnerPhotos() }
            syncReceivedRatingsFromCloud()
        }
    }

    /// Mesh arka planla uyum: opak kart yerine lavanta‑cyan süzülü malzeme + ince kenarlık.
    private func harmonyPanelBackdrop(cornerRadius: CGFloat = 24) -> some View {
        HarmonyPanelChrome.panelBackdrop(cornerRadius: cornerRadius, colorScheme: colorScheme)
    }

    /// Kart gölgesi — mesh üzerinde daha yumuşak
    private var harmonyCardShadowColor: Color {
        HarmonyPanelChrome.cardShadow(colorScheme: colorScheme)
    }

    /// List + NavigationLink kendi disclosure ikonunu gösterdiği için çift ok olmasın.
    private var displayedHistoryItems: [CompatibilityHistoryItem] {
        Array(sortedItems.prefix(visibleCount))
    }

    private var sonAnalizlerHeaderRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Son Analizler")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Menu {
                sortOptionButton(.latest, title: "En Yeni")
                sortOptionButton(.aiScore, title: "AI Uyum")
                sortOptionButton(.myScore, title: "Senin Puanın")
                sortOptionButton(.receivedScore, title: "Sana Verilen")
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 40, height: 40)
                    .background(HarmonyPanelChrome.toolbarRoundGlass(diameter: 40, colorScheme: colorScheme))
            }
            .menuStyle(.button)
        }
    }

    private var loadMoreHistoryRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                visibleCount = min(visibleCount + 8, sortedItems.count)
            }
        } label: {
            Text("Daha Fazla Göster")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Material.thin)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.08), lineWidth: 1)
                        }
                )
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
    }

    private func deleteHistoryItem(_ item: CompatibilityHistoryItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            CompatibilityHistoryStore.remove(at: IndexSet(integer: idx))
        }
        reloadHistory()
    }

    private func reloadHistory() {
        items = CompatibilityHistoryStore.load()
        visibleCount = min(max(visibleCount, 8), max(items.count, 8))
    }

    private func syncReceivedRatingsFromCloud() {
        Task {
            await CompatibilityHistoryStore.syncReceivedRatings()
            reloadHistory()
        }
    }

    private var sortedItems: [CompatibilityHistoryItem] {
        switch sortOption {
        case .latest:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .aiScore:
            return items.sorted {
                if $0.ai.percent == $1.ai.percent { return $0.createdAt > $1.createdAt }
                return $0.ai.percent > $1.ai.percent
            }
        case .myScore:
            return items.sorted {
                let lhs = $0.myRating?.overallScore ?? -1
                let rhs = $1.myRating?.overallScore ?? -1
                if lhs == rhs { return $0.createdAt > $1.createdAt }
                return lhs > rhs
            }
        case .receivedScore:
            return items.sorted {
                let lhs = $0.receivedRating?.overallScore ?? -1
                let rhs = $1.receivedRating?.overallScore ?? -1
                if lhs == rhs { return $0.createdAt > $1.createdAt }
                return lhs > rhs
            }
        }
    }

    @ViewBuilder
    private func sortOptionButton(_ option: HistorySortOption, title: String) -> some View {
        Button {
            sortOption = option
        } label: {
            if sortOption == option {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func preloadPartnerPhotos() async {
        for item in items where partnerPhotoURLs[item.id] == nil {
            if let url = try? await fetchPartnerPhotoURL(partnerQuery: item.partnerQuery),
               !url.isEmpty {
                partnerPhotoURLs[item.id] = url
            }
        }

        for item in items where partnerDisplayNames[item.id] == nil {
            if let name = try? await fetchPartnerDisplayName(partnerQuery: item.partnerQuery),
               !name.isEmpty {
                partnerDisplayNames[item.id] = name
            } else {
                partnerDisplayNames[item.id] = sanitizedName(item.partnerQuery)
            }
        }
    }

    private var summaryInsights: some View {
        let avgAI = items.isEmpty ? 0 : items.map(\.ai.percent).reduce(0, +) / items.count
        let best = items.map(\.ai.percent).max() ?? 0

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("TOPLAM ANALİZ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(items.count)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Kayıtlı analiz adedi")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)
            .background(
                harmonyPanelBackdrop(cornerRadius: 24)
                    .shadow(color: harmonyCardShadowColor, radius: 14, x: 0, y: 8)
            )

            HStack(spacing: 12) {
                insightMiniCard(
                    icon: "heart.fill",
                    iconColor: Color(mtHex: 0x6D53E6),
                    value: "%\(avgAI)",
                    title: "Ortalama Uyum"
                )
                insightMiniCard(
                    icon: "bolt.fill",
                    iconColor: Color(mtHex: 0x0D9488),
                    value: "%\(best)",
                    title: "En Yüksek Skor"
                )
            }
        }
    }

    private func insightMiniCard(
        icon: String,
        iconColor: Color,
        value: String,
        title: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            harmonyPanelBackdrop(cornerRadius: 24)
                .shadow(color: harmonyCardShadowColor, radius: 12, x: 0, y: 6)
        )
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Geçmiş henüz boş")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Text("Uyum sekmesinden AI analizi yaptıktan sonra geçmişin burada listelenir.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            harmonyPanelBackdrop(cornerRadius: 24)
                .shadow(color: harmonyCardShadowColor, radius: 12, x: 0, y: 6)
        )
    }

    private func historyCard(item: CompatibilityHistoryItem, showsAccessoryChevron: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                partnerAvatar(for: item, side: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(partnerDisplayNames[item.id] ?? sanitizedName(item.partnerQuery))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(formattedDate(item.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                if showsAccessoryChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(width: 34, height: 34)
                        .background {
                            Circle()
                                .fill(Material.ultraThinMaterial)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.07),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .accessibilityHidden(true)
                }
            }

            historyMetricRingsRow(for: item)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            harmonyPanelBackdrop(cornerRadius: 24)
                .shadow(color: harmonyCardShadowColor, radius: 12, x: 0, y: 6)
        )
    }

    private func historyRingsSectionTotalHeight(ringDiameter: CGFloat) -> CGFloat {
        let labelBlock: CGFloat = 28
        let ringToLabelSpacing: CGFloat = 7
        return ringDiameter + ringToLabelSpacing + labelBlock
    }

    private func historyRingLayout(contentWidth: CGFloat) -> (ringDiameter: CGFloat, columnWidth: CGFloat, gap: CGFloat) {
        let gap: CGFloat = 14
        let col = max(1, (contentWidth - 2 * gap) / 3)
        // Biraz daha dolgun görünsün; tavan düşürülüp çizgi kalınlığı ile dengelendi.
        let ring = min(56, max(46, col * 0.82))
        return (ring, col, gap)
    }

    private func historyRingsBlockHeightEstimate() -> CGFloat {
        let cardHorizontal: CGFloat = 18 * 4
        let ringsHorizontalInset: CGFloat = 12 * 2
        let listW = UIScreen.main.bounds.width - cardHorizontal - ringsHorizontalInset
        let l = historyRingLayout(contentWidth: listW)
        return historyRingsSectionTotalHeight(ringDiameter: l.ringDiameter)
    }

    /// Hafif yan boşluk + üç eşit sütun; her sütunda daire ve yazılar ortalı.
    private func historyMetricRingsRow(for item: CompatibilityHistoryItem) -> some View {
        let horizontalInset: CGFloat = 12
        return GeometryReader { geo in
            let contentW = max(geo.size.width, 1)
            let layout = historyRingLayout(contentWidth: contentW)
            let rowHeight = historyRingsSectionTotalHeight(ringDiameter: layout.ringDiameter)
            HStack(alignment: .top, spacing: layout.gap) {
                HistoryMetricRingCell(
                    title: "AI Uyum",
                    percent: item.ai.percent as Int?,
                    kind: .ai,
                    diameter: layout.ringDiameter,
                    columnWidth: layout.columnWidth
                )
                HistoryMetricRingCell(
                    title: "Senin Puanın",
                    percent: item.myRating?.overallScore,
                    kind: .myScore,
                    diameter: layout.ringDiameter,
                    columnWidth: layout.columnWidth
                )
                HistoryMetricRingCell(
                    title: "Sana Verilen",
                    percent: item.receivedRating?.overallScore,
                    kind: .received,
                    diameter: layout.ringDiameter,
                    columnWidth: layout.columnWidth
                )
            }
            .frame(width: contentW, height: rowHeight, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: historyRingsBlockHeightEstimate())
        .padding(.horizontal, horizontalInset)
        .padding(.top, 10)
    }
    private func partnerAvatar(for item: CompatibilityHistoryItem, side: CGFloat = 56) -> some View {
        let radius = side * (14 / 56)
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(mtHex: 0xEEF2FF),
                            Color(mtHex: 0xE0E7FF),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let raw = partnerPhotoURLs[item.id], !raw.isEmpty,
               let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: min(24, side * 0.4), weight: .semibold))
                            .foregroundStyle(Color(mtHex: 0x7C3AED).opacity(0.72))
                    @unknown default:
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: min(24, side * 0.4), weight: .semibold))
                            .foregroundStyle(Color(mtHex: 0x7C3AED).opacity(0.72))
                    }
                }
            } else {
                Image(systemName: "person.crop.square.fill")
                    .font(.system(size: min(24, side * 0.4), weight: .semibold))
                    .foregroundStyle(Color(mtHex: 0x7C3AED).opacity(0.72))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func sanitizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Bilinmeyen Kullanıcı" }
        if trimmed.hasPrefix("vbc1."), trimmed.count > 14 {
            let p = String(trimmed.prefix(6))
            let s = String(trimmed.suffix(4))
            return "\(p)...\(s)"
        }
        if trimmed.hasPrefix("+90") { return trimmed }
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst()).capitalized
        }
        return trimmed
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Bugün, \(date.formatted(.dateTime.hour().minute()))"
        }
        if calendar.isDateInYesterday(date) {
            return "Dün, \(date.formatted(.dateTime.hour().minute()))"
        }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    private func fetchPartnerPhotoURL(partnerQuery: String) async throws -> String? {
        guard let data = try await fetchDiscoverabilityData(partnerQuery: partnerQuery) else { return nil }
        return resolvePhotoURL(from: data)
    }

    private func fetchPartnerDisplayName(partnerQuery: String) async throws -> String? {
        guard let data = try await fetchDiscoverabilityData(partnerQuery: partnerQuery),
              let fullName = data["fullName"] as? String else { return nil }
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fetchDiscoverabilityData(partnerQuery: String) async throws -> [String: Any]? {
        let db = Firestore.firestore()
        let q = partnerQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        let digits = q.filter(\.isNumber)
        if (q.hasPrefix("+") || digits.count >= 10) && !digits.isEmpty {
            let e164: String
            if digits.count == 12, digits.hasPrefix("90") {
                e164 = "+\(digits)"
            } else if digits.count == 10 {
                e164 = "+90\(digits)"
            } else {
                e164 = q
            }

            let snap = try await db
                .collection("discoverabilityUsers")
                .whereField("phoneE164", isEqualTo: e164)
                .limit(to: 1)
                .getDocuments()
            if let data = snap.documents.first?.data() {
                return data
            }
        }

        if q.hasPrefix("@") || q.range(of: #"^[a-z0-9_]{1,15}$"#, options: .regularExpression) != nil {
            let user = q.hasPrefix("@") ? String(q.dropFirst()) : q
            let username = user.lowercased()
            let snap = try await db
                .collection("discoverabilityUsers")
                .whereField("xUsernameLower", isEqualTo: username)
                .limit(to: 1)
                .getDocuments()
            if let data = snap.documents.first?.data() {
                return data
            }
        }

        if q.hasPrefix("vbc1.") {
            let vSnap = try await db
                .collection("discoverabilityUsers")
                .whereField("vibeCode", isEqualTo: q)
                .limit(to: 1)
                .getDocuments()
            if let data = vSnap.documents.first?.data() {
                return data
            }
        }

        return nil
    }

    private func resolvePhotoURL(from data: [String: Any]) -> String? {
        let keys = ["photoPublicURL", "photoURL", "profilePhotoURL", "avatarURL"]
        for key in keys {
            if let value = data[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }
}
