import Foundation

/// Host-facing listing type.
///
/// Experiences are separate from Tours so Hosts can have distinct listings.
struct Experience: Codable, Identifiable, Hashable {
    let id: String
    var hostId: String
    var title: String
    var description: String
    var city: String
    var country: String? = nil
    /// Optional street address or meeting point.
    var address: String? = nil
    var coverPhotoURL: String?
    var latitude: Double?
    var longitude: Double?
    var durationMinutes: Int
    var price: Double
    var maxPeople: Int
    /// If true, traveler can book without provider approval. Optional for backward compatibility.
    var instantBook: Bool? = nil
    // Marketplace enrichment
    var category: String? = nil
    var difficulty: String? = nil
    var physicalEffort: String? = nil
    var authenticityScore: Int? = nil
    /// Optional smart pricing rules + promo campaigns
    var smartPricing: SmartPricing? = nil
    // Ratings
    var ratingAvg: Double? = nil
    var ratingCount: Int? = nil
    var weightedScore: Double? = nil
    var weeklyScore: Double? = nil
    var cancellationPolicy: CancellationPolicy? = nil
    var active: Bool
    var createdAt: Date

    // Hashable / Equatable based on stable id (required for NavigationStack destinations)
    static func == (lhs: Experience, rhs: Experience) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
