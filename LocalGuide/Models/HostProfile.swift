import Foundation

/// Hosts publish cultural experiences (not licensed tour guiding).
struct HostProfile: Codable, Identifiable {
    let id: String
    var brandName: String
    var country: String
    var city: String
    var categories: [String]   // e.g. cooking, wine, crafts
    var bio: String
    var photoURL: String?
    // Ratings
    var ratingAvg: Double = 0
    var ratingCount: Int = 0
    var createdAt: Date
}
