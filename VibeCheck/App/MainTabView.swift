import SwiftUI
import FirebaseFirestore

/// Giriş tamamlandıktan ve ilk kurulum pipeline’ı bittikten sonra görünen ana kabuk (tab’lar).
struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ProfileEditorView()
            }
            .tabItem {
                Label("Profil", systemImage: "person.circle.fill")
            }

            NavigationStack {
                CompatibilityAnalysisView()
            }
            .tabItem {
                Label("Uyum", systemImage: "heart.text.square.fill")
            }

            NavigationStack {
                CompatibilityHistoryView()
            }
            .tabItem {
                Label("Geçmiş", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            NavigationStack {
                SettingsTabView()
            }
            .tabItem {
                Label("Ayarlar", systemImage: "gearshape.fill")
            }
        }
        .tint(.pink)
    }
}

private struct CompatibilityHistoryView: View {
    @State private var items: [CompatibilityHistoryItem] = CompatibilityHistoryStore.load()
    @State private var visibleCount = 8
    @State private var isEditing = false
    @State private var partnerPhotoURLs: [UUID: String] = [:]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryInsights

                Text("Son Analizler")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                if items.isEmpty {
                    emptyStateCard
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(items.prefix(visibleCount))) { item in
                            if isEditing {
                                editingHistoryCard(item: item)
                            } else {
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
                                    historyCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                            CompatibilityHistoryStore.remove(at: IndexSet(integer: idx))
                                            reloadHistory()
                                        }
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    if visibleCount < items.count {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                visibleCount = min(visibleCount + 8, items.count)
                            }
                        } label: {
                            Text("Daha Fazla Göster")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 120)
        }
        .navigationTitle("Geçmiş")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Bitti" : "Edit") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                    }
                }
                    .foregroundStyle(Color(hex: 0xE51245))
            }
        }
        .onAppear {
            reloadHistory()
            Task { await preloadPartnerPhotos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: CompatibilityHistoryStore.didUpdateNotification)) { _ in
            reloadHistory()
            Task { await preloadPartnerPhotos() }
        }
        .background(
            LinearGradient(
                colors: historyBackgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func reloadHistory() {
        items = CompatibilityHistoryStore.load()
        visibleCount = min(max(visibleCount, 8), max(items.count, 8))
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

    private func historyCard(item: CompatibilityHistoryItem) -> some View {
        HStack(spacing: 12) {
            partnerAvatar(for: item)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(sanitizedName(item.partnerQuery))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(formattedDate(item.createdAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    metricColumn(
                        label: "AI UYUMU",
                        value: "%\(item.ai.percent)",
                        tint: Color(hex: 0xBA0034)
                    )
                    Rectangle()
                        .fill(Color(.separator).opacity(0.3))
                        .frame(width: 1, height: 24)
                    metricColumn(
                        label: "PUANLAMA",
                        value: item.myRating.map { "%\($0.overallScore)" } ?? "--",
                        tint: Color(hex: 0x4C4ACA)
                    )
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }

    private func editingHistoryCard(item: CompatibilityHistoryItem) -> some View {
        HStack(spacing: 10) {
            historyCard(item: item)
            Button(role: .destructive) {
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    CompatibilityHistoryStore.remove(at: IndexSet(integer: idx))
                    reloadHistory()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func metricColumn(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
        }
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
                return resolvePhotoURL(from: data)
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
                return resolvePhotoURL(from: data)
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

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex & 0xFF0000) >> 16) / 255.0
        let g = Double((hex & 0x00FF00) >> 8) / 255.0
        let b = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

#Preview {
    MainTabView()
}
