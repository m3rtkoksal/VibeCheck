import SwiftUI
import UIKit
import FirebaseFirestore

// MARK: - Ana sekmeler üst çubuğu (SettingsTabView ile aynı düzen)

private enum MainTabGlassTopPalette {
    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color(hex: 0xE9E7ED).opacity(0.4)
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
                    .foregroundStyle(Color(hex: 0xE51245))
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

/// Giriş tamamlandıktan ve ilk kurulum pipeline’ı bittikten sonra görünen ana kabuk (tab’lar).
struct MainTabView: View {
    @State private var selectedTab: MainTab = .history

    init() {
        MainTabViewChrome.configureTransparentStacks()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            nestedNavigation {
                ProfileEditorView()
            }
            .tag(MainTab.profile)
            .tabItem {
                Label("Profil", systemImage: "person.circle.fill")
            }

            nestedNavigation {
                CompatibilityAnalysisView()
            }
            .tag(MainTab.compatibility)
            .tabItem {
                Label("Uyum", systemImage: "heart.text.square.fill")
            }

            nestedNavigation {
                CompatibilityHistoryView()
            }
            .tag(MainTab.history)
            .tabItem {
                Label("Geçmiş", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            nestedNavigation {
                SettingsTabView()
            }
            .tag(MainTab.settings)
            .tabItem {
                Label("Ayarlar", systemImage: "gearshape.fill")
            }
        }
        .background {
            HostingScrollSurfaceClearTrigger()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .background(Color.clear)
        .toolbarBackground(Color.clear, for: .tabBar)
        .tint(.pink)
        .onReceive(NotificationCenter.default.publisher(for: .vibecheckOpenHistoryTab)) { _ in
            selectedTab = .history
        }
        .onAppear {
            MainTabViewChrome.clearMainWindowBackgroundIfNeeded()
        }
    }

    /// Mesh bu `NavigationStack` katmanına bağlanır; `TabView` arkası tek başına görünür olmayabiliyor.
    /// Kök görünüm `Color.clear` kalmalı.
    private func nestedNavigation<Content: View>(@ViewBuilder root: () -> Content) -> some View {
        NavigationStack {
            ZStack {
                MeshAuroraBackgroundView()
                    .ignoresSafeArea()
                root()
                    .background(Color.clear)
            }
        }
        .toolbarBackground(Color.clear, for: .navigationBar)
    }
}

// MARK: - Tab / Nav host arka plan (UIKit)

private enum MainTabViewChrome {
    static func clearMainWindowBackgroundIfNeeded() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.backgroundColor = .clear
            }
        }
    }

    static func configureTransparentStacks() {
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundColor = .clear
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tab
        tabBar.scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .clear
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = nav
        bar.scrollEdgeAppearance = nav
        bar.compactAppearance = nav
        bar.compactScrollEdgeAppearance = nav
        bar.isTranslucent = true

        UIScrollView.appearance().backgroundColor = .clear
        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }
}

// MARK: - List / koleksiyon host opak zemini

/// SwiftUI `List` (özellikle iOS 17+) bazı durumlarda `UITableView` / `UICollectionView` kökünde sistem beyazını bırakıyor;
/// `UITableView.appearance()` yetmeyebiliyor — penceredeki örnekleri doğrudan temizler.
private struct HostingScrollSurfaceClearTrigger: UIViewRepresentable {
    final class Coordinator {
        weak var attachedWindow: UIWindow?
        var debounceWork: DispatchWorkItem?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let window = uiView.window else { return }

        context.coordinator.debounceWork?.cancel()
        let work = DispatchWorkItem {
            HostingScrollSurfaceClearTrigger.clearOpaqueScrollSurfaces(from: window)
            context.coordinator.attachedWindow = window
        }
        context.coordinator.debounceWork = work
        DispatchQueue.main.async(execute: work)
    }

    private static func clearOpaqueScrollSurfaces(from root: UIView) {
        var stack: [UIView] = [root]
        var visited = Set<ObjectIdentifier>()
        while let v = stack.popLast() {
            let oid = ObjectIdentifier(v)
            if visited.contains(oid) { continue }
            visited.insert(oid)

            if let tv = v as? UITableView {
                tv.backgroundColor = .clear
                tv.isOpaque = false
            }
            if let cv = v as? UICollectionView {
                cv.backgroundColor = .clear
                cv.isOpaque = false
            }

            stack.append(contentsOf: v.subviews)
        }
    }
}

private enum MainTab: Hashable {
    case profile
    case compatibility
    case history
    case settings
}

/// `List` içindeki `NavigationLink` sistem `>` okunu hücreye taşır; programatik hedefle kaldırılır.
private enum HistoryDetailRoute: Hashable {
    case analysis(UUID)
}

private struct CompatibilityHistoryView: View {
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
                    .foregroundStyle(Color(hex: 0xE51245))
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
                harmonyPanelBackdrop(cornerRadius: 24)
                    .shadow(color: harmonyCardShadowColor, radius: 14, x: 0, y: 8)
            )

            HStack(spacing: 12) {
                insightMiniCard(
                    icon: "heart.fill",
                    iconColor: Color(hex: 0x6D53E6),
                    value: "%\(avgAI)",
                    title: "Ortalama Uyum"
                )
                insightMiniCard(
                    icon: "bolt.fill",
                    iconColor: Color(hex: 0x0D9488),
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
        VStack(alignment: .leading, spacing: 14) {
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

            HStack(spacing: 8) {
                metricChip(
                    label: "AI Uyum",
                    value: "%\(item.ai.percent)",
                    kind: .ai
                )
                metricChip(
                    label: "Senin Puanın",
                    value: item.myRating.map { "%\($0.overallScore)" } ?? "Bekleniyor",
                    kind: .myScore
                )
                metricChip(
                    label: "Sana Verilen",
                    value: item.receivedRating.map { "%\($0.overallScore)" } ?? "Bekleniyor",
                    kind: .received
                )
            }
        }
        .padding(18)
        .background(
            harmonyPanelBackdrop(cornerRadius: 24)
                .shadow(color: harmonyCardShadowColor, radius: 12, x: 0, y: 6)
        )
    }

    private enum HistoryMetricChipKind {
        case ai
        case myScore
        case received

        /// `harmonyPanelBackdrop` ile aynı pastel hâl (pembe / mor / cyan).
        func labelTint(_ scheme: ColorScheme) -> Color {
            switch self {
            case .ai:
                return Color(hex: scheme == .dark ? 0xFDA4AF : 0xE11D48)
            case .myScore:
                return Color(hex: scheme == .dark ? 0xC4B5FD : 0x6D28D9)
            case .received:
                return Color(hex: scheme == .dark ? 0x67E8F9 : 0x0891B2)
            }
        }

        func mistGradient(_ scheme: ColorScheme) -> LinearGradient {
            let d = scheme == .dark
            switch self {
            case .ai:
                return LinearGradient(
                    colors: [
                        Color(hex: 0xFF2D55).opacity(d ? 0.38 : 0.2),
                        Color(hex: 0xF9A8D4).opacity(d ? 0.22 : 0.14),
                        Color(hex: 0xFFF1F9).opacity(d ? 0.14 : 0.38),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .myScore:
                return LinearGradient(
                    colors: [
                        Color(hex: 0x7C3AED).opacity(d ? 0.35 : 0.18),
                        Color(hex: 0xDDD6FE).opacity(d ? 0.2 : 0.22),
                        Color(hex: 0xEDE9FE).opacity(d ? 0.1 : 0.35),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .received:
                return LinearGradient(
                    colors: [
                        Color(hex: 0x0891B2).opacity(d ? 0.38 : 0.16),
                        Color(hex: 0x22D3EE).opacity(d ? 0.2 : 0.12),
                        Color(hex: 0xBAE6FD).opacity(d ? 0.12 : 0.32),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        func strokeColor(_ scheme: ColorScheme) -> Color {
            switch self {
            case .ai:
                return Color(hex: 0xFB7185).opacity(scheme == .dark ? 0.38 : 0.2)
            case .myScore:
                return Color(hex: 0xA78BFA).opacity(scheme == .dark ? 0.42 : 0.18)
            case .received:
                return Color(hex: 0x38BDF8).opacity(scheme == .dark ? 0.4 : 0.16)
            }
        }

        /// Yüzde satırı için siyah yerine sıcak, okunaklı ton.
        func valueTint(_ scheme: ColorScheme) -> Color {
            switch self {
            case .ai:
                return scheme == .dark ? Color(hex: 0xFECDD3) : Color(hex: 0x9F1239)
            case .myScore:
                return scheme == .dark ? Color(hex: 0xE9D5FF) : Color(hex: 0x5B21B6)
            case .received:
                return scheme == .dark ? Color(hex: 0xCCFBF1) : Color(hex: 0x134E4A)
            }
        }
    }

    private func metricChip(label: String, value: String, kind: HistoryMetricChipKind) -> some View {
        let isPercentageValue = value.hasPrefix("%")

        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(kind.labelTint(colorScheme).opacity(colorScheme == .dark ? 0.82 : 0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(value)
                .font(
                    isPercentageValue
                        ? .system(size: 21, weight: .semibold, design: .rounded)
                        : .system(size: 11, weight: .medium)
                )
                .foregroundStyle(isPercentageValue ? kind.valueTint(colorScheme) : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(isPercentageValue ? 0.52 : 0.88)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(minHeight: 72)
        .background(chipBackdrop(kind: kind))
    }

    /// Küçük skor kutusu — kart `harmonyPanel` ile aynı renk ailesi (pembe / lavanta / cyan).
    private func chipBackdrop(kind: HistoryMetricChipKind) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(Material.ultraThinMaterial)
            shape.fill(kind.mistGradient(colorScheme))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(kind.strokeColor(colorScheme), lineWidth: 0.75))
    }

    private func partnerAvatar(for item: CompatibilityHistoryItem, side: CGFloat = 56) -> some View {
        let radius = side * (14 / 56)
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xEEF2FF),
                            Color(hex: 0xFCE7F3),
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
                            .foregroundStyle(Color(hex: 0x7C3AED).opacity(0.72))
                    @unknown default:
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: min(24, side * 0.4), weight: .semibold))
                            .foregroundStyle(Color(hex: 0x7C3AED).opacity(0.72))
                    }
                }
            } else {
                Image(systemName: "person.crop.square.fill")
                    .font(.system(size: min(24, side * 0.4), weight: .semibold))
                    .foregroundStyle(Color(hex: 0x7C3AED).opacity(0.72))
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
            Group {
                if reduceTransparency {
                    Circle()
                        .fill(colorScheme == .dark ? Color(hex: 0x2A3244) : Color(hex: 0xFFFFFF))
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
