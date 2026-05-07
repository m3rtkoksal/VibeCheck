import Foundation

struct ProfileSnapshot: Codable {
    /// Versioned payload so we can evolve format later.
    let v: Int
    /// categoryId -> option string
    let selections: [String: String]
    /// unix timestamp (seconds)
    let ts: Int

    static func fromLocalDefaults() -> ProfileSnapshot {
        var selections: [String: String] = [:]
        for category in ProfileCategory.allCases {
            let key = "profile.category.\(category.id)"
            let value = UserDefaults.standard.string(forKey: key) ?? ""
            if !value.isEmpty {
                selections[category.id] = value
            }
        }

        return ProfileSnapshot(
            v: 1,
            selections: selections,
            ts: Int(Date().timeIntervalSince1970)
        )
    }
}

