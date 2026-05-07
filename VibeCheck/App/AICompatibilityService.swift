import Foundation
import FirebaseFunctions

struct AICompatibilityInsight: Codable {
    let percent: Int
    let strengths: [String]
    let frictions: [String]
    let summary: String
    let forecasts: [Forecast]?
    let icebreakers: [Icebreaker]?

    init(
        percent: Int,
        strengths: [String],
        frictions: [String],
        summary: String,
        forecasts: [Forecast]? = nil,
        icebreakers: [Icebreaker]? = nil
    ) {
        self.percent = percent
        self.strengths = strengths
        self.frictions = frictions
        self.summary = summary
        self.forecasts = forecasts
        self.icebreakers = icebreakers
    }

    struct Forecast: Codable, Hashable {
        let id: String
        let title: String
        let risk: String
        let description: String
        let tip: String
    }

    struct Icebreaker: Codable, Hashable {
        let topic: String
        let prompt: String
    }
}

struct AISelfProfileInsight: Codable {
    let summary: String
    let aboutYou: [String]
    let relationshipStyle: String
    let gentleReminders: [String]
    let traitBreakdown: [Trait]?

    struct Trait: Codable, Hashable {
        /// Stable id like "introversion"
        let id: String
        /// Display title like "INTROVERSION"
        let title: String
        /// 0-100
        let percent: Int
        /// 1-2 sentence explanation
        let description: String
    }
}

enum AICompatibilityService {
    static func analyzeViaFirebase(
        me: ProfileSnapshot,
        partner: ProfileSnapshot,
        privateNote: String
    ) async throws -> AICompatibilityInsight {
        let functions = Functions.functions(region: "europe-west1")
        let callable = functions.httpsCallable("analyzeCompatibility")

        let payload: [String: Any] = [
            "me": try snapshotToDict(me),
            "partner": try snapshotToDict(partner),
            "privateNote": privateNote,
        ]

        let result = try await callable.call(payload)
        guard let dict = result.data as? [String: Any] else {
            throw AICompatibilityError.invalidResponse
        }

        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(AICompatibilityInsight.self, from: data)
    }

    static func analyzeSelfProfile(
        me: ProfileSnapshot,
        privateNote: String
    ) async throws -> AISelfProfileInsight {
        let functions = Functions.functions(region: "europe-west1")
        let callable = functions.httpsCallable("analyzeSelfProfile")

        let payload: [String: Any] = [
            "me": try snapshotToDict(me),
            "privateNote": privateNote,
        ]

        let result = try await callable.call(payload)
        guard let dict = result.data as? [String: Any] else {
            throw AICompatibilityError.invalidResponse
        }

        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(AISelfProfileInsight.self, from: data)
    }

    private static func snapshotToDict(_ snapshot: ProfileSnapshot) throws -> [String: Any] {
        let data = try JSONEncoder().encode(snapshot)
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw AICompatibilityError.invalidResponse
        }
        return dict
    }
}

enum AICompatibilityError: Error, Equatable {
    case invalidResponse
}

