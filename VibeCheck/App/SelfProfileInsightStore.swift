import Foundation
import CryptoKit

/// Kayıtlı kişisel karakter analizi ve profil içeriği parmak izi (yeniden analiz gereksinimini tespit için).
enum SelfProfileInsightStore {
    private static let storageKey = "profile.selfInsight.payload.v1"

    struct Payload: Codable {
        let insight: AISelfProfileInsight
        let contentFingerprint: String
        let savedAt: Date
    }

    /// Sorular + özel not birleşiminin sabit özeti; API’ye giden veriyle uyumlu olmalı.
    static func currentFingerprint() -> String {
        var lines: [String] = []
        for cat in ProfileCategory.allCases.sorted(by: { $0.id < $1.id }) {
            let value = UserDefaults.standard.string(forKey: "profile.category.\(cat.id)") ?? ""
            lines.append("\(cat.id)=\(value)")
        }
        let note = UserDefaults.standard.string(forKey: "profile.privateNote") ?? ""
        lines.append("privateNote=\(note)")
        let raw = lines.joined(separator: "\u{1e}")
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func load() -> Payload? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    static func save(insight: AISelfProfileInsight) {
        let payload = Payload(
            insight: insight,
            contentFingerprint: currentFingerprint(),
            savedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Kayıt yok veya parmak izi profilden farklı.
    static func isStaleComparedToProfile() -> Bool {
        guard let payload = load() else { return true }
        return payload.contentFingerprint != currentFingerprint()
    }

    enum InsightBadge: Equatable {
        case none
        case missingAnalysis
        case needsRefresh
    }

    /// Profil tab satırı için kısa durum.
    static func profileTabBadge(isProfileComplete: Bool) -> InsightBadge {
        if load() == nil {
            return isProfileComplete ? .missingAnalysis : .none
        }
        if isStaleComparedToProfile() {
            return .needsRefresh
        }
        return .none
    }
}
