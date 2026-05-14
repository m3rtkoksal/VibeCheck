import Combine
import FirebaseFunctions
import Foundation

extension Notification.Name {
    /// `VoiceProfileInsightStore.save` başarısından sonra (UI yenilemesi için).
    static let voiceProfileInsightDidUpdate = Notification.Name("VoiceProfileInsightDidUpdate")
}

/// Sunucunun döndürdüğü ses analizi (`transcript` hep boş — metin dökümü yok).
struct AIVoiceProfileInsight: Codable, Equatable {
    let transcript: String
    let summary: String
    /// 3–5 kısa madde iletişim / ilişki sinyali.
    let signals: [String]
    let energyPerspective: String
    let tonePerspective: String
    let pacingPerspective: String

    enum CodingKeys: String, CodingKey {
        case transcript
        case summary
        case signals
        case energyPerspective
        case tonePerspective
        case pacingPerspective
    }

    init(
        transcript: String,
        summary: String,
        signals: [String],
        energyPerspective: String,
        tonePerspective: String,
        pacingPerspective: String
    ) {
        self.transcript = transcript
        self.summary = summary
        self.signals = signals
        self.energyPerspective = energyPerspective
        self.tonePerspective = tonePerspective
        self.pacingPerspective = pacingPerspective
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        transcript = try c.decode(String.self, forKey: .transcript)
        summary = try c.decode(String.self, forKey: .summary)
        signals = try c.decodeIfPresent([String].self, forKey: .signals) ?? []
        energyPerspective =
            try c.decodeIfPresent(String.self, forKey: .energyPerspective) ?? ""
        tonePerspective =
            try c.decodeIfPresent(String.self, forKey: .tonePerspective) ?? ""
        pacingPerspective =
            try c.decodeIfPresent(String.self, forKey: .pacingPerspective) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(transcript, forKey: .transcript)
        try c.encode(summary, forKey: .summary)
        try c.encode(signals, forKey: .signals)
        try c.encode(energyPerspective, forKey: .energyPerspective)
        try c.encode(tonePerspective, forKey: .tonePerspective)
        try c.encode(pacingPerspective, forKey: .pacingPerspective)
    }
}

enum VoiceAnalysisError: Error, Equatable {
    case invalidResponse
    case fileMissing
    case fileTooLarge(Int)
}

enum VoiceAnalysisService {
    /// Sunucunun kabulü ile uyumlu üst boyut (~1.5 MiB ham PCM WAV ~15 sn mono).
    private static let maxAudioBytes = 1_572_864

    static func analyzeRecordedSampleAtSampleURL(readingPrompt: String) async throws -> AIVoiceProfileInsight {
        try await DiscoverabilityAuthService.prepareForHttpsCallable()

        let url = VoiceCharacterSampleFile.sampleURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VoiceAnalysisError.fileMissing
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maxAudioBytes else {
            throw VoiceAnalysisError.fileTooLarge(data.count)
        }
        guard !data.isEmpty else {
            throw VoiceAnalysisError.fileMissing
        }

        let b64 = data.base64EncodedString()

        let functions = Functions.functions(region: "europe-west1")
        let callable = functions.httpsCallable("analyzeVoiceProfile")

        let payload: [String: Any] = [
            "audioBase64": b64,
            "readingPrompt": readingPrompt,
        ]

        let result = try await callable.call(payload)
        guard let dict = result.data as? [String: Any] else {
            throw VoiceAnalysisError.invalidResponse
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(AIVoiceProfileInsight.self, from: jsonData)
    }

    /// Kayıttan sonra gecikmeli sheet kapanmasından sonra da çalışır.
    static func analyzeAndPersist(readingPrompt: String) async {
        do {
            let insight = try await analyzeRecordedSampleAtSampleURL(readingPrompt: readingPrompt)
            await MainActor.run {
                VoiceProfileInsightStore.save(insight: insight)
                NotificationCenter.default.post(name: .voiceProfileInsightDidUpdate, object: nil)
            }
        } catch {
            NSLog("[VoiceAnalysis] failed: %@", String(describing: error))
        }
    }
}
