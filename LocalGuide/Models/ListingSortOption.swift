import Foundation

enum ListingSortOption: String, CaseIterable, Identifiable {
    case bestRated
    case mostReviewed
    case newest
    case soonestAvailable
    case topThisWeek
    case bestWeighted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestRated: return "Best rated"
        case .mostReviewed: return "Most reviews"
        case .newest: return "Newest"
        case .soonestAvailable: return "Soonest available"
        case .topThisWeek: return "Top rated this week"
        case .bestWeighted: return "Best overall (weighted)"
        }
    }
}
