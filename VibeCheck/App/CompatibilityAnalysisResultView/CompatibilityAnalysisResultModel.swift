import Foundation
import FirebaseAuth
import FirebaseFirestore

struct AIOnlyAnalysisOutput: Identifiable {
    let id: UUID
    let partnerQuery: String
    let ai: AICompatibilityInsight
    let historyId: UUID?
    let myRating: DateEvaluation?
    let receivedRating: DateEvaluation?
    /// Gelen puan bildirimi: Firestore'daki doküman kimliği (karşılık puanlama tamamlanınca geçmişe yazılır).
    let incomingFirestoreDocId: String?

    init(
        id: UUID = UUID(),
        partnerQuery: String,
        ai: AICompatibilityInsight,
        historyId: UUID? = nil,
        myRating: DateEvaluation? = nil,
        receivedRating: DateEvaluation? = nil,
        incomingFirestoreDocId: String? = nil
    ) {
        self.id = id
        self.partnerQuery = partnerQuery
        self.ai = ai
        self.historyId = historyId
        self.myRating = myRating
        self.receivedRating = receivedRating
        self.incomingFirestoreDocId = incomingFirestoreDocId
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
    /// Yerel liste ile gelen puan bildirimi eşlemesi (yedek çözüm için).
    let incomingRatingDocID: String?
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
            receivedRating: output.receivedRating,
            incomingRatingDocID: output.incomingFirestoreDocId
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
                receivedRating: old.receivedRating,
                incomingRatingDocID: old.incomingRatingDocID
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
                receivedRating: old.receivedRating,
                incomingRatingDocID: old.incomingRatingDocID
            )
            save(current)
        }
    }

    /// Ayarlar ile aynı UserDefaults anahtarı (tam ad bildirimi metninde kullanılır).
    static func resolvedRaterPublicNameForPublishing() -> String {
        let fromDefaults =
            UserDefaults.standard.string(forKey: "discoverability.fullName")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromDefaults.isEmpty {
            return fromDefaults
        }
        if let n = Auth.auth().currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !n.isEmpty {
            return n
        }
        return ""
    }

    static func publishMyRating(
        partnerQuery: String,
        rating: DateEvaluation,
        sharedAI: AICompatibilityInsight,
        raterPublicName: String
    ) async {
        guard let raterUID = Auth.auth().currentUser?.uid else { return }
        do {
            guard let targetUID = try await resolvePartnerUID(partnerQuery: partnerQuery),
                  !targetUID.isEmpty else {
                NSLog(
                    "[CompatibilityHistoryStore] publishMyRating: hedef UID çözülemedi (Vibe Code / telefon / @kullanıcı tam ve satır sonu olmadan eşleşmeli): %@",
                    partnerQuery
                )
                return
            }

            let pairKey = [raterUID, targetUID].sorted().joined(separator: "::")
            var payload = firestoreMap(for: rating)
            payload["raterUID"] = raterUID
            payload["targetUID"] = targetUID
            payload["pairKey"] = pairKey
            payload["createdAt"] = FieldValue.serverTimestamp()

            let aiData = try JSONEncoder().encode(sharedAI)
            if let aiStr = String(data: aiData, encoding: .utf8) {
                payload["sharedAIJson"] = aiStr
            }

            let trimmedName = raterPublicName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                payload["raterPublicName"] = trimmedName
            }

            if let hint = try await resolvedPartnerQueryHintForPublishing(raterUID: raterUID)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
               !hint.isEmpty {
                payload["partnerQueryHint"] = hint
            }

            try await Firestore.firestore()
                .collection("compatibilityRatings")
                .addDocument(data: payload)
            NSLog(
                "[CompatibilityHistoryStore] publishMyRating: Firestore’a yazıldı (hedef=%@, puanlayan=%@)",
                targetUID,
                raterUID
            )
        } catch {
            NSLog("[CompatibilityHistoryStore] publishMyRating error: %@", error.localizedDescription)
        }
    }

    /// Gelen bildirimi açarken kullanıcı adı için: rater'in discoverability belgesinden en iyi görünür tanımlayıcı.
    static func decodeSharedAIInsight(fromFirestore data: [String: Any]) -> AICompatibilityInsight? {
        guard let raw = data["sharedAIJson"] as? String,
              let blob = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AICompatibilityInsight.self, from: blob)
    }

    static func syncReceivedRatings() async {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("compatibilityRatings")
                .whereField("targetUID", isEqualTo: myUID)
                .getDocuments()

            var latestByRater: [String: (Date, DateEvaluation)] = [:]
            for doc in snapshot.documents {
                let data = doc.data()
                guard let raterUID = data["raterUID"] as? String,
                      let rating = ratingFromFirestore(data) else { continue }
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
                if let existing = latestByRater[raterUID], existing.0 >= createdAt {
                    continue
                }
                latestByRater[raterUID] = (createdAt, rating)
            }

            guard !latestByRater.isEmpty else { return }

            var current = load()
            guard !current.isEmpty else { return }

            var partnerUIDCache: [String: String?] = [:]
            var changed = false

            for idx in current.indices {
                let query = current[idx].partnerQuery
                let partnerUID: String?
                if let cached = partnerUIDCache[query] {
                    partnerUID = cached
                } else {
                    let resolved = try await resolvePartnerUID(partnerQuery: query)
                    partnerUIDCache[query] = resolved
                    partnerUID = resolved
                }

                guard let partnerUID,
                      let incoming = latestByRater[partnerUID]?.1 else { continue }

                if !ratingsEqual(current[idx].receivedRating, incoming) {
                    let old = current[idx]
                    current[idx] = CompatibilityHistoryItem(
                        id: old.id,
                        createdAt: old.createdAt,
                        partnerQuery: old.partnerQuery,
                        ai: old.ai,
                        myRating: old.myRating,
                        receivedRating: incoming,
                        incomingRatingDocID: old.incomingRatingDocID
                    )
                    changed = true
                }
            }

            if changed {
                save(current)
            }
        } catch {
            NSLog("[CompatibilityHistoryStore] syncReceivedRatings error: %@", error.localizedDescription)
        }
    }

    static func resolvedPartnerQueryHintForPublishing(raterUID: String) async throws -> String? {
        let doc = try await Firestore.firestore()
            .collection("discoverabilityUsers")
            .document(raterUID)
            .getDocument()
        guard let data = doc.data() else { return nil }
        if let x = data["xUsernameLower"] as? String,
           !x.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "@\(x.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }
        if let phone = data["phoneE164"] as? String,
           !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DiscoverabilityAuthService.normalizedE164Phone(phone)
        }
        if let vibe = data["vibeCode"] as? String,
           !vibe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return vibe.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Gelen bildirim satırından puan çıkarma.
    static func ratingFromFirestorePublic(_ data: [String: Any]) -> DateEvaluation? {
        ratingFromFirestore(data)
    }

    private static func save(_ items: [CompatibilityHistoryItem]) {
        guard
            let data = try? JSONEncoder().encode(items),
            let raw = String(data: data, encoding: .utf8)
        else { return }

        UserDefaults.standard.set(raw, forKey: key)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }

    private static func resolvePartnerUID(partnerQuery: String) async throws -> String? {
        guard let lookup = normalizedLookup(for: partnerQuery) else { return nil }
        let snap = try await Firestore.firestore()
            .collection("discoverabilityUsers")
            .whereField(lookup.field, isEqualTo: lookup.value)
            .limit(to: 1)
            .getDocuments()
        return snap.documents.first?.documentID
    }

    private static func normalizedLookup(for rawQuery: String) -> (field: String, value: String)? {
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        if q.hasPrefix("vbc1.") {
            return ("vibeCode", q)
        }

        let normalizedPhone = DiscoverabilityAuthService.normalizedE164Phone(q)
        if normalizedPhone.hasPrefix("+"), normalizedPhone.count >= 8 {
            return ("phoneE164", normalizedPhone)
        }

        let rawUser = q.hasPrefix("@") ? String(q.dropFirst()) : q
        let username = rawUser.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !username.isEmpty,
           username.range(of: #"^[a-z0-9_]{1,15}$"#, options: .regularExpression) != nil {
            return ("xUsernameLower", username)
        }

        return nil
    }

    private static func firestoreMap(for rating: DateEvaluation) -> [String: Any] {
        [
            "egoScore": rating.egoScore,
            "sincerityScore": rating.sincerityScore,
            "intentScore": rating.intentScore,
            "flowScore": rating.flowScore,
            "sexualFocusScore": rating.sexualFocusScore,
            "showedStatus": rating.showedStatus,
            "redFlag": rating.redFlag,
            "overallScore": rating.overallScore,
        ]
    }

    private static func ratingFromFirestore(_ data: [String: Any]) -> DateEvaluation? {
        guard let ego = intValue(data["egoScore"]),
              let sincerity = intValue(data["sincerityScore"]),
              let intent = intValue(data["intentScore"]),
              let flow = intValue(data["flowScore"]),
              let sexualFocus = intValue(data["sexualFocusScore"]),
              let showedStatus = data["showedStatus"] as? Bool,
              let redFlag = data["redFlag"] as? Bool,
              let overall = intValue(data["overallScore"]) else { return nil }

        return DateEvaluation(
            egoScore: ego,
            sincerityScore: sincerity,
            intentScore: intent,
            flowScore: flow,
            sexualFocusScore: sexualFocus,
            showedStatus: showedStatus,
            redFlag: redFlag,
            overallScore: overall
        )
    }

    private static func intValue(_ any: Any?) -> Int? {
        switch any {
        case let value as Int:
            return value
        case let value as Int64:
            return Int(value)
        case let value as NSNumber:
            return value.intValue
        case let value as Double:
            return Int(value.rounded())
        default:
            return nil
        }
    }

    private static func ratingsEqual(_ lhs: DateEvaluation?, _ rhs: DateEvaluation) -> Bool {
        guard let lhs else { return false }
        return lhs.egoScore == rhs.egoScore
            && lhs.sincerityScore == rhs.sincerityScore
            && lhs.intentScore == rhs.intentScore
            && lhs.flowScore == rhs.flowScore
            && lhs.sexualFocusScore == rhs.sexualFocusScore
            && lhs.showedStatus == rhs.showedStatus
            && lhs.redFlag == rhs.redFlag
            && lhs.overallScore == rhs.overallScore
    }
}
