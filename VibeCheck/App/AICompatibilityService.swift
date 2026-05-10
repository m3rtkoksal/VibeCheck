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
    let gentleReminders: [String]
    let traitBreakdown: [Trait]?

    enum CodingKeys: String, CodingKey {
        case summary
        case aboutYou
        case gentleReminders
        case traitBreakdown
    }

    init(
        summary: String,
        aboutYou: [String],
        gentleReminders: [String],
        traitBreakdown: [Trait]?
    ) {
        self.summary = summary
        self.aboutYou = aboutYou
        self.gentleReminders = gentleReminders
        self.traitBreakdown = traitBreakdown
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decode(String.self, forKey: .summary)
        aboutYou = try c.decodeIfPresent([String].self, forKey: .aboutYou) ?? []
        gentleReminders =
            try c.decodeIfPresent([String].self, forKey: .gentleReminders) ?? []
        traitBreakdown = try c.decodeIfPresent([Trait].self, forKey: .traitBreakdown)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(summary, forKey: .summary)
        try c.encode(aboutYou, forKey: .aboutYou)
        try c.encode(gentleReminders, forKey: .gentleReminders)
        try c.encodeIfPresent(traitBreakdown, forKey: .traitBreakdown)
    }

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

