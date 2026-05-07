import Foundation

struct AIOnlyAnalysisOutput: Identifiable {
    let id: UUID
    let partnerQuery: String
    let ai: AICompatibilityInsight
    let historyId: UUID?
    let myRating: DateEvaluation?
    let receivedRating: DateEvaluation?

    init(
        id: UUID = UUID(),
        partnerQuery: String,
        ai: AICompatibilityInsight,
        historyId: UUID? = nil,
        myRating: DateEvaluation? = nil,
        receivedRating: DateEvaluation? = nil
    ) {
        self.id = id
        self.partnerQuery = partnerQuery
        self.ai = ai
        self.historyId = historyId
        self.myRating = myRating
        self.receivedRating = receivedRating
    }
}

struct DateEvaluation: Codable {
    let egoScore: Int
    let sincerityScore: Int
    let intentScore: Int
    let flowScore: Int
    let sexualFocusScore: Int
    let showedStatus: Bool
    let redFlag: Bool
    let overallScore: Int
}

struct CompatibilityHistoryItem: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let partnerQuery: String
    let ai: AICompatibilityInsight
    let myRating: DateEvaluation?
    let receivedRating: DateEvaluation?
}

enum CompatibilityHistoryStore {
    private static let key = "compatibility.history.items.v1"
    static let didUpdateNotification = Notification.Name("compatibility.history.updated")

    static func load() -> [CompatibilityHistoryItem] {
        guard
            let raw = UserDefaults.standard.string(forKey: key),
            let data = raw.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([CompatibilityHistoryItem].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    static func append(from output: AIOnlyAnalysisOutput) -> CompatibilityHistoryItem {
        var current = load()
        let item = CompatibilityHistoryItem(
            id: UUID(),
            createdAt: Date(),
            partnerQuery: output.partnerQuery,
            ai: output.ai,
            myRating: output.myRating,
            receivedRating: output.receivedRating
        )
        current.insert(item, at: 0)
        save(current)
        return item
    }

    static func remove(at offsets: IndexSet) {
        var current = load()
        current.remove(atOffsets: offsets)
        save(current)
    }

    static func updateRating(
        historyId: UUID?,
        partnerQuery: String,
        rating: DateEvaluation
    ) {
        var current = load()
        if let historyId,
           let idx = current.firstIndex(where: { $0.id == historyId }) {
            let old = current[idx]
            current[idx] = CompatibilityHistoryItem(
                id: old.id,
                createdAt: old.createdAt,
                partnerQuery: old.partnerQuery,
                ai: old.ai,
                myRating: rating,
                receivedRating: old.receivedRating
            )
            save(current)
            return
        }

        if let idx = current.firstIndex(where: { $0.partnerQuery == partnerQuery }) {
            let old = current[idx]
            current[idx] = CompatibilityHistoryItem(
                id: old.id,
                createdAt: old.createdAt,
                partnerQuery: old.partnerQuery,
                ai: old.ai,
                myRating: rating,
                receivedRating: old.receivedRating
            )
            save(current)
        }
    }

    private static func save(_ items: [CompatibilityHistoryItem]) {
        guard
            let data = try? JSONEncoder().encode(items),
            let raw = String(data: data, encoding: .utf8)
        else { return }

        UserDefaults.standard.set(raw, forKey: key)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }
}
