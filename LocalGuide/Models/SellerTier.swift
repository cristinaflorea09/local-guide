import Foundation

/// Stripe subscription tier for sellers (Guides / Hosts).
enum SellerTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case elite = "elite"

    var title: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .elite: return "Elite"
        }
    }
}
