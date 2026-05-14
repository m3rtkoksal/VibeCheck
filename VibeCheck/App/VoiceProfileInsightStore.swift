import Foundation

enum VoiceProfileInsightStore {
    private static let storageKey = "profile.voiceInsight.payload.v1"

    struct Payload: Codable {
        let insight: AIVoiceProfileInsight
        let savedAt: Date
    }

    static func load() -> Payload? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    static func save(insight: AIVoiceProfileInsight) {
        let payload = Payload(insight: insight, savedAt: Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
