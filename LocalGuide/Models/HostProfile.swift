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
    /// When true, this provider wants to receive custom requests from travelers.
    /// Optional for backward compatibility with older documents.
    var acceptsCustomRequests: Bool? = nil
    // Ratings
    var ratingAvg: Double = 0
    var ratingCount: Int = 0
    var createdAt: Date
}

