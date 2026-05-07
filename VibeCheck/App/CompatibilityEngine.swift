import Foundation

enum CompatibilityEngine {
    static func compute(me: ProfileSnapshot, partner: ProfileSnapshot) -> CompatibilityResult {
        let categories = ProfileCategory.allCases
        var scores: [Double] = []
        var strengths: [String] = []
        var frictions: [String] = []

        for category in categories {
            let a = me.selections[category.id] ?? ""
            let b = partner.selections[category.id] ?? ""
            guard !a.isEmpty, !b.isEmpty else { continue }

            let score = categoryScore(category: category, a: a, b: b)
            scores.append(score)

            if score >= 0.9 {
                strengths.append("\(category.title): benzer (\(a))")
            } else if score <= 0.35 {
                frictions.append("\(category.title): farklı (\(a) vs \(b))")
            }
        }

        let avg = scores.isEmpty ? 0.0 : (scores.reduce(0, +) / Double(scores.count))
        return CompatibilityResult(
            percent: avg * 100.0,
            strengths: strengths,
            frictions: frictions
        )
    }

    private static func categoryScore(category: ProfileCategory, a: String, b: String) -> Double {
        // v1: use option index distance. Same=1.0, adjacent=0.6, far=0.2
        guard let ai = category.options.firstIndex(of: a),
              let bi = category.options.firstIndex(of: b) else { return 0.5 }
        let d = abs(ai - bi)
        switch d {
        case 0: return 1.0
        case 1: return 0.6
        default: return 0.2
        }
    }
}

struct CompatibilityResult {
    let percent: Double
    let strengths: [String]
    let frictions: [String]
}

