import Foundation

struct Tour: Codable, Identifiable {
    let id: String
    var guideId: String
    var title: String
    var description: String
    var city: String
    var coverPhotoURL: String?
    var latitude: Double?
    var longitude: Double?
    var durationMinutes: Int
    var price: Double
    var maxPeople: Int
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
    /// Custom cancellation policy configured per listing.
    var cancellationPolicy: CancellationPolicy? = nil
    var active: Bool
    var createdAt: Date
}
