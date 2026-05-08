import Foundation
import SwiftUI
import UIKit

struct ResultReasonItem {
    let title: String
    let text: String
}

struct ResultIcebreakerItem {
    let topic: String
    let prompt: String
}

struct ResultForecastItem {
    let title: String
    let text: String
    let risk: String
    let tip: String
}

enum ResultTopTab: CaseIterable {
    case uyum
    case buzkiran
    case ongoru
    case degerlendirme
    case puanim

    var title: String {
        switch self {
        case .uyum: return "Uyum"
        case .buzkiran: return "Buzkıran"
        case .ongoru: return "Öngörü"
        case .degerlendirme: return "Puanla"
        case .puanim: return "Puanım"
        }
    }
}

@MainActor
final class CompatibilityAnalysisResultViewModel: ObservableObject {
    let output: AIOnlyAnalysisOutput

    @Published var selectedTab: ResultTopTab = .uyum
    @Published var copiedBuzkiranIndex: Int?
    @Published var myAvatarUIImage: UIImage?
    @Published var egoScore: Double = 5
    @Published var sincerityScore: Double = 7
    @Published var intentScore: Double = 6
    @Published var flowScore: Double = 8
    @Published var sexualFocusScore: Double = 3
    @Published var showedStatus = false
    @Published var redFlag = false
    @Published var showSavedAlert = false
    @Published private(set) var hasSavedRating = false
    @Published private(set) var receivedRating: DateEvaluation?

    init(output: AIOnlyAnalysisOutput) {
        self.output = output
        hasSavedRating = output.myRating != nil
        receivedRating = output.receivedRating
        applyExistingRatingIfAny()
        refreshReceivedRatingFromHistory()
    }

    var canSaveRating: Bool {
        !hasSavedRating
    }

    var reasonItems: [ResultReasonItem] {
        let preferred = output.ai.strengths.prefix(2)
        if preferred.count == 2 {
            return [
                ResultReasonItem(title: "Ortak Değerler", text: preferred[preferred.startIndex]),
                ResultReasonItem(
                    title: "İletişim Tarzı",
                    text: preferred[preferred.index(after: preferred.startIndex)]
                ),
            ]
        }
        if preferred.count == 1 {
            return [
                ResultReasonItem(title: "Ortak Değerler", text: preferred[preferred.startIndex]),
                ResultReasonItem(
                    title: "İletişim Tarzı",
                    text: "Karşılıklı anlayış ve açık iletişim potansiyeliniz yüksek."
                ),
            ]
        }
        return [
            ResultReasonItem(
                title: "Ortak Değerler",
                text: "Benzer ilişki değerleri ve beklentiler öne çıkıyor."
            ),
            ResultReasonItem(
                title: "İletişim Tarzı",
                text: "Açık ve yargısız bir iletişim kurma eğiliminiz güçlü."
            ),
        ]
    }

    var buzkiranItems: [ResultIcebreakerItem] {
        if let fromAI = output.ai.icebreakers, !fromAI.isEmpty {
            return fromAI.map { ResultIcebreakerItem(topic: $0.topic, prompt: $0.prompt) }
        }

        return [
            ResultIcebreakerItem(
                topic: "Hafta Sonu Planları",
                prompt: "Bu hafta sonu seni en çok heyecanlandıracak plan ne olurdu?"
            ),
            ResultIcebreakerItem(
                topic: "Günlük Rutin",
                prompt: "Günün en keyifli anı genelde senin için hangi saatlerde oluyor?"
            ),
            ResultIcebreakerItem(
                topic: "Müzik / Film",
                prompt: "Son zamanlarda tekrar tekrar dinlediğin bir şarkı var mı?"
            ),
            ResultIcebreakerItem(
                topic: "Seyahat",
                prompt: "Kısa bir kaçamak yapsak senin ilk seçeceğin rota neresi olurdu?"
            ),
        ]
    }

    var forecastItems: [ResultForecastItem] {
        if let forecasts = output.ai.forecasts, !forecasts.isEmpty {
            return forecasts.map { item in
                ResultForecastItem(
                    title: item.title,
                    text: item.description,
                    risk: item.risk,
                    tip: item.tip
                )
            }
        }

        let template: [(title: String, risk: String, tip: String)] = [
            (
                "Finansal Yaklaşım",
                "DİKKAT",
                "Bütçe konuşmalarını \"kısıtlama\" değil, \"ortak hedef\" çerçevesinde yapın."
            ),
            (
                "Stres Yönetimi",
                "ORTA RİSK",
                "Tansiyon yükselince kısa bir mola verip daha sakin tonda geri dönün."
            ),
            (
                "Sosyal Enerji",
                "HAFİF",
                "Hafta planlarında bir sosyal, bir sakin zaman dengesi kurmanız uyumu artırır."
            ),
        ]

        let texts = output.ai.frictions.isEmpty
            ? ["Yakın dönemde büyük bir sürtüşme sinyali görünmüyor; net iletişimle güçlü bir denge korunabilir."]
            : Array(output.ai.frictions.prefix(3))

        return texts.enumerated().map { idx, text in
            let t = template[min(idx, template.count - 1)]
            return ResultForecastItem(title: t.title, text: text, risk: t.risk, tip: t.tip)
        }
    }

    var partnerLabel: String {
        let q = output.partnerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.hasPrefix("@") {
            return String(q.dropFirst()).capitalized
        }
        if q.hasPrefix("+90") || q.isEmpty {
            return "Partner"
        }
        return q.capitalized
    }

    func loadAvatar(photoSaved: Bool) {
        myAvatarUIImage = photoSaved ? ProfilePhotoStore.load() : nil
    }

    func saveRating() {
        guard canSaveRating else { return }
        let rating = buildDateEvaluation()
        CompatibilityHistoryStore.append(
            from: AIOnlyAnalysisOutput(
                partnerQuery: output.partnerQuery,
                ai: output.ai,
                myRating: rating,
                receivedRating: output.receivedRating
            )
        )
        Task {
            await CompatibilityHistoryStore.publishMyRating(partnerQuery: output.partnerQuery, rating: rating)
            await CompatibilityHistoryStore.syncReceivedRatings()
            refreshReceivedRatingFromHistory()
        }
        hasSavedRating = true
        showSavedAlert = true
    }

    func buildDateEvaluation() -> DateEvaluation {
        let ego = Int(egoScore.rounded())
        let sincerity = Int(sincerityScore.rounded())
        let intent = Int(intentScore.rounded())
        let flow = Int(flowScore.rounded())
        let sexual = Int(sexualFocusScore.rounded())

        let components = [11 - ego, sincerity, intent, flow, 11 - sexual]
        var normalized = (components.reduce(0, +) * 100) / 50
        if showedStatus { normalized -= 8 }
        if redFlag { normalized -= 18 }
        normalized = max(0, min(100, normalized))

        return DateEvaluation(
            egoScore: ego,
            sincerityScore: sincerity,
            intentScore: intent,
            flowScore: flow,
            sexualFocusScore: sexual,
            showedStatus: showedStatus,
            redFlag: redFlag,
            overallScore: normalized
        )
    }

    private func applyExistingRatingIfAny() {
        guard let r = output.myRating else { return }
        egoScore = Double(r.egoScore)
        sincerityScore = Double(r.sincerityScore)
        intentScore = Double(r.intentScore)
        flowScore = Double(r.flowScore)
        sexualFocusScore = Double(r.sexualFocusScore)
        showedStatus = r.showedStatus
        redFlag = r.redFlag
    }

    func refreshReceivedRating() {
        Task {
            await CompatibilityHistoryStore.syncReceivedRatings()
            await MainActor.run {
                refreshReceivedRatingFromHistory()
            }
        }
    }

    private func refreshReceivedRatingFromHistory() {
        let key = output.partnerQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else {
            receivedRating = output.receivedRating
            return
        }

        let latest = CompatibilityHistoryStore
            .load()
            .filter { $0.partnerQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap(\.receivedRating)
            .first

        receivedRating = latest ?? output.receivedRating
    }
}
