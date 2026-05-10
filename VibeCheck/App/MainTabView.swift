import SwiftUI
import FirebaseFirestore

// MARK: - Ana sekmeler üst çubuğu (SettingsTabView ile aynı düzen)

private enum MainTabGlassTopPalette {
    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color(hex: 0xE9E7ED)
    }
}

struct MainTabGlassTopBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                leading()

                Spacer(minLength: 0)

                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .default))
                    .tracking(-1)
                    .foregroundStyle(Color(hex: 0xFF2D55))

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
        .background(.regularMaterial.opacity(colorScheme == .dark ? 0.88 : 0.94))
    }
}

/// Giriş tamamlandıktan ve ilk kurulum pipeline’ı bittikten sonra görünen ana kabuk (tab’lar).
struct MainTabView: View {
    @State private var selectedTab: MainTab = .history

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ProfileEditorView()
            }
            .tag(MainTab.profile)
            .tabItem {
                Label("Profil", systemImage: "person.circle.fill")
            }

            NavigationStack {
                CompatibilityAnalysisView()
            }
            .tag(MainTab.compatibility)
            .tabItem {
                Label("Uyum", systemImage: "heart.text.square.fill")
            }

            NavigationStack {
                CompatibilityHistoryView()
            }
            .tag(MainTab.history)
            .tabItem {
                Label("Geçmiş", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            NavigationStack {
                SettingsTabView()
            }
            .tag(MainTab.settings)
            .tabItem {
                Label("Ayarlar", systemImage: "gearshape.fill")
            }
        }
        .tint(.pink)
        .onReceive(NotificationCenter.default.publisher(for: .vibecheckOpenHistoryTab)) { _ in
            selectedTab = .history
        }
    }
}

private enum MainTab: Hashable {
    case profile
    case compatibility
    case history
    case settings
}

private struct CompatibilityHistoryView: View {
    @State private var items: [CompatibilityHistoryItem] = CompatibilityHistoryStore.load()
    @State private var visibleCount = 8
    @State private var partnerPhotoURLs: [UUID: String] = [:]
    @State private var partnerDisplayNames: [UUID: String] = [:]
    @State private var sortOption: HistorySortOption = .latest
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: historyBackgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
                            .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 10, trailing: 18))
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
                                NavigationLink {
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
                                } label: {
                                    historyCard(item: item, showsAccessoryChevron: false)
                                        .contentShape(Rectangle())
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 14))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteHistoryItem(item)
                                    } label: {
                                        Label("Sil", systemImage: "trash.fill")
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
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
        }
        .navigationBarHidden(true)
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

    /// List + NavigationLink kendi disclosure ikonunu gösterdiği için çift ok olmasın.
    private var displayedHistoryItems: [CompatibilityHistoryItem] {
        Array(sortedItems.prefix(visibleCount))
    }

    private var sonAnalizlerHeaderRow: some View {
        HStack {
            Text("Son Analizler")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                sortOptionButton(.latest, title: "En Yeni")
                sortOptionButton(.aiScore, title: "AI Uyum")
                sortOptionButton(.myScore, title: "Senin Puanın")
                sortOptionButton(.receivedScore, title: "Sana Verilen")
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xE51245))
            }
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
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
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

    private var historyBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: 0x0B0C12),
                Color(hex: 0x11131E),
                Color(hex: 0x17111E),
            ]
        } else {
            return [
                Color(hex: 0xFAF9FE),
                Color(hex: 0xF4F3F8),
                Color.white,
            ]
        }
    }

    private func preloadPartnerPhotos() async {
        for item in items where partnerPhotoURLs[item.id] == nil {
            if let url = try? await fetchPartnerPhotoURL(partnerQuery: item.partnerQuery),
               !url.isEmpty {
                partnerPhotoURLs[item.id] = url
            } else {
                partnerPhotoURLs[item.id] = ""
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
                            .foregroundStyle(Color(hex: 0xE51245))
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: 0xE51245))
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
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)
            )

            HStack(spacing: 12) {
                insightMiniCard(
                    icon: "heart.fill",
                    iconColor: Color(hex: 0x4C4ACA),
                    value: "%\(avgAI)",
                    title: "Ortalama Uyum"
                )
                insightMiniCard(
                    icon: "bolt.fill",
                    iconColor: Color(hex: 0x00855F),
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

    private func historyCard(item: CompatibilityHistoryItem, showsAccessoryChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            partnerAvatar(for: item)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(partnerDisplayNames[item.id] ?? sanitizedName(item.partnerQuery))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(formattedDate(item.createdAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    metricChip(
                        label: "AI Uyum",
                        value: "%\(item.ai.percent)",
                        tint: Color(hex: 0xBA0034)
                    )
                    metricChip(
                        label: "Senin Puanın",
                        value: item.myRating.map { "%\($0.overallScore)" } ?? "Bekleniyor",
                        tint: Color(hex: 0x4C4ACA)
                    )
                    metricChip(
                        label: "Sana Verilen",
                        value: item.receivedRating.map { "%\($0.overallScore)" } ?? "Bekleniyor",
                        tint: Color(hex: 0x00855F)
                    )
                }
            }

            if showsAccessoryChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

    private func metricChip(label: String, value: String, tint: Color) -> some View {
        let isPercentageValue = value.hasPrefix("%")

        return VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(height: 14, alignment: .topLeading)

            Text(value)
                .font(
                    isPercentageValue
                        ? .system(size: 30, weight: .black, design: .rounded)
                        : .system(size: 12, weight: .semibold)
                )
                .foregroundStyle(isPercentageValue ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(isPercentageValue ? 0.45 : 0.55)
                .allowsTightening(true)
                .padding(.bottom, isPercentageValue ? 0 : 3)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .bottomLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 84, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.16),
                    tint.opacity(0.05),
                    Color(.secondarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func partnerAvatar(for item: CompatibilityHistoryItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xFFE8EE))

            if let raw = partnerPhotoURLs[item.id], !raw.isEmpty,
               let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xBA0034).opacity(0.6))
                    }
                }
            } else {
                Image(systemName: "person.crop.square.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xBA0034).opacity(0.6))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        let keys = ["photoURL", "profilePhotoURL", "avatarURL"]
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

private enum HistorySortOption {
    case latest
    case aiScore
    case myScore
    case receivedScore
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// Ana sekmelerde paylaşılan puan bildirimi çanı (Profil ile aynı görünüm).
struct IncomingNotificationsToolbarButton: View {
    @ObservedObject private var incomingRatings = IncomingCompatibilityRatingsNotifier.shared
    @Environment(\.colorScheme) private var colorScheme

    private var badgeWellFill: Color {
        colorScheme == .dark ? Color(hex: 0x2A3244) : Color(hex: 0xFFFFFF)
    }

    private var bellTint: Color {
        colorScheme == .dark ? Color(hex: 0x5C8EFF) : Color(hex: 0x004BE3)
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
            Circle()
                .fill(badgeWellFill)
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
                            .background(Capsule(style: .continuous).fill(Color(hex: 0xE51245)))
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

#Preview {
    MainTabView()
}
