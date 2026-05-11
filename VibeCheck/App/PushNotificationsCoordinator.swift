import Foundation
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

extension Notification.Name {
    /// Bildirim dokunulduğunda Geçmiş sekmesine geç.
    static let vibecheckOpenHistoryTab = Notification.Name("vibecheckOpenHistoryTab")
}

enum UserPushTokenSync {
    /// Mevcut FCM token'ı Firestore'a yazar (logged-in kullanıcı için).
    static func persist(token: String) async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            // Firestore isteğinde geçerli ID token olsun diye (oturum yenileme / yarış).
            _ = try await user.getIDToken()
            try await Firestore.firestore()
                .collection("userPushTokens")
                .document(user.uid)
                .setData(
                    [
                        "token": token,
                        "updatedAt": FieldValue.serverTimestamp(),
                    ],
                    merge: true
                )
        } catch {
            NSLog("[Push] FCM token yazılamadı: %@", error.localizedDescription)
        }
    }

    static func refreshMessagingRegistration() {
        guard Messaging.messaging().apnsToken != nil else {
            // Simülatör / APNs yoksa FCM token isteği hata döndürür (log gürültüsü).
            return
        }
        Messaging.messaging().token { token, error in
            if let error {
                NSLog("[Push] FCM token alınamadı: %@", error.localizedDescription)
                return
            }
            guard let token else { return }
            Task { await persist(token: token) }
        }
    }

    @MainActor
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            refreshMessagingRegistration()
        } catch {
            NSLog("[Push] Bildirim izni alınamadı: %@", error.localizedDescription)
        }
    }
}

// MARK: - Görüldü (rozet sıfır; liste yine aksiyonda kalır)

private enum IncomingRatingSeenPersistence {
    private static func key(uid: String) -> String {
        "vibecheck.seenIncomingRatingDocIds.\(uid)"
    }

    /// Çok uzun süre sonra UserDefaults şişmesin (rozet görünmeyen id’leri at).
    private static let maxStoredIds = 400

    static func load(uid: String) -> Set<String> {
        guard let arr = UserDefaults.standard.stringArray(forKey: key(uid: uid)) else { return [] }
        return Set(arr)
    }

    static func save(uid: String, ids: Set<String>) {
        let trimmed: [String] = ids.count <= maxStoredIds
            ? Array(ids)
            : Array(ids.suffix(maxStoredIds))
        UserDefaults.standard.set(trimmed, forKey: key(uid: uid))
    }
}

struct IncomingCompatibilityRatingPendingRow: Identifiable {
    let id: String
    let raterDisplayName: String
    let partnerQuery: String
    let receivedRating: DateEvaluation
    let sharedAI: AICompatibilityInsight

    var rateBackOutput: AIOnlyAnalysisOutput {
        AIOnlyAnalysisOutput(
            partnerQuery: partnerQuery,
            ai: sharedAI,
            historyId: nil,
            myRating: nil,
            receivedRating: receivedRating,
            incomingFirestoreDocId: id
        )
    }
}

/// Firestore uyum puanları: gelen bildirim kuyruğu + rozet.
@MainActor
final class IncomingCompatibilityRatingsNotifier: ObservableObject {
    static let shared = IncomingCompatibilityRatingsNotifier()

    @Published private(set) var pendingRows: [IncomingCompatibilityRatingPendingRow] = []

    /// Rozet için: daha önce “görüldü” olarak kaydedilmiş gelen dokümanlar çan sayısından düşülür (UserDefaults).
    private var seenIncomingDocIDs = Set<String>()

    private var inboundListener: ListenerRegistration?
    private var outboundListener: ListenerRegistration?
    private var outboundPairKeys: Set<String> = []
    private var lastInboundDocuments: [QueryDocumentSnapshot] = []

    private init() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.stopListeners()
                self.pendingRows = []
                self.outboundPairKeys = []
                self.lastInboundDocuments = []
                if let uid = user?.uid {
                    self.seenIncomingDocIDs = IncomingRatingSeenPersistence.load(uid: uid)
                    self.startListeners()
                }
            }
        }
    }

    var badgeCount: Int {
        pendingRows.filter { !seenIncomingDocIDs.contains($0.id) }.count
    }

    /// Puan bildirimi listesi görünür: mevcut + sonradan eklenen satırları da görüldü say (liste `onChange` ile).
    func markSeenMatchingCurrentInbox(rows: [IncomingCompatibilityRatingPendingRow]) {
        markSeen(for: rows.map(\.id))
    }

    /** Detay açılınca: gelen tek doküman çan/rozet sıfırlandı olarak kaydedilir. */
    func markIncomingDetailOpened(docId: String?) {
        guard let docId, !docId.isEmpty else { return }
        markSeen(for: [docId])
    }

    private func markSeen(for ids: [String]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = ids.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        let before = seenIncomingDocIDs.count
        seenIncomingDocIDs.formUnion(trimmed)
        guard seenIncomingDocIDs.count != before else { return }
        IncomingRatingSeenPersistence.save(uid: uid, ids: seenIncomingDocIDs)
        objectWillChange.send()
    }

    private func startListeners() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        seenIncomingDocIDs = IncomingRatingSeenPersistence.load(uid: uid)
        stopListeners()
        let db = Firestore.firestore()

        inboundListener = db.collection("compatibilityRatings")
            .whereField("targetUID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    NSLog("[IncomingRatings] inbound: %@", error.localizedDescription)
                    return
                }
                Task { @MainActor in
                    if let snap = snapshot {
                        self.lastInboundDocuments = snap.documents
                    }
                    await self.recomputePendingRows()
                }
            }

        outboundListener = db.collection("compatibilityRatings")
            .whereField("raterUID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    NSLog("[IncomingRatings] outbound: %@", error.localizedDescription)
                    return
                }
                var keys = Set<String>()
                for doc in snapshot?.documents ?? [] {
                    if let pk = doc.data()["pairKey"] as? String, !pk.isEmpty {
                        keys.insert(pk)
                    }
                }
                Task { @MainActor in
                    self.outboundPairKeys = keys
                    await self.recomputePendingRows()
                }
            }
    }

    private func stopListeners() {
        inboundListener?.remove()
        inboundListener = nil
        outboundListener?.remove()
        outboundListener = nil
    }

    private func recomputePendingRows() async {
        var latestByPair: [String: QueryDocumentSnapshot] = [:]
        for doc in lastInboundDocuments {
            let data = doc.data()
            let pk = (data["pairKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = (pk?.isEmpty == false) ? pk! : doc.documentID
            let created = (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
            if let existing = latestByPair[key] {
                let oldDate = (existing.data()["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
                if created >= oldDate {
                    latestByPair[key] = doc
                }
            } else {
                latestByPair[key] = doc
            }
        }

        var rows: [IncomingCompatibilityRatingPendingRow] = []
        for (_, doc) in latestByPair {
            let data = doc.data()
            let pairKey = (data["pairKey"] as? String) ?? ""
            if !pairKey.isEmpty, outboundPairKeys.contains(pairKey) {
                continue
            }

            guard let raterUID = data["raterUID"] as? String, !raterUID.isEmpty,
                  let received = CompatibilityHistoryStore.ratingFromFirestorePublic(data) else { continue }

            let name = (data["raterPublicName"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let raterDisplay = (name?.isEmpty == false) ? name! : "Biri"

            var partnerQuery = (data["partnerQueryHint"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if partnerQuery.isEmpty {
                partnerQuery = (try? await CompatibilityHistoryStore
                    .resolvedPartnerQueryHintForPublishing(raterUID: raterUID))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }

            guard !partnerQuery.isEmpty else { continue }

            let sharedAI = CompatibilityHistoryStore.decodeSharedAIInsight(fromFirestore: data)
                ?? AICompatibilityInsight(
                    percent: received.overallScore,
                    strengths: [],
                    frictions: [],
                    summary: "Bu puan için paylaşılan AI analizi yüklenemedi; yüzdeler için puan özeti kullanıldı.",
                    forecasts: nil,
                    icebreakers: nil
                )

            rows.append(
                IncomingCompatibilityRatingPendingRow(
                    id: doc.documentID,
                    raterDisplayName: raterDisplay,
                    partnerQuery: partnerQuery,
                    receivedRating: received,
                    sharedAI: sharedAI
                )
            )
        }

        let docById = Dictionary(uniqueKeysWithValues: lastInboundDocuments.map { ($0.documentID, $0) })
        rows.sort { a, b in
            let da = docById[a.id].flatMap { ($0.data()["createdAt"] as? Timestamp)?.dateValue() } ?? .distantPast
            let dbDate = docById[b.id].flatMap { ($0.data()["createdAt"] as? Timestamp)?.dateValue() }
                ?? .distantPast
            return da > dbDate
        }

        pendingRows = rows
    }
}
