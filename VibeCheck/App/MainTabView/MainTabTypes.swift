import Foundation

enum MainTab: Hashable {
    case profile
    case compatibility
    case history
    case settings
}

/// `List` içindeki `NavigationLink` sistem `>` okunu hücreye taşır; programatik hedefle kaldırılır.
enum HistoryDetailRoute: Hashable {
    case analysis(UUID)
}

enum HistorySortOption {
    case latest
    case aiScore
    case myScore
    case receivedScore
}
