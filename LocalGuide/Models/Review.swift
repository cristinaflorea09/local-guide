import Foundation

struct Review: Codable, Identifiable {
    let id: String
    /// "tour" or "experience"
    var listingType: String
    /// tourId or experienceId
    var listingId: String
    /// guideId or hostId
    var providerEmail: String
    /// "guide" or "host" (optional but useful for analytics)
    var providerRole: String?
    /// booking id this review is associated with (prevents duplicates)
    var bookingId: String?
    var userId: String
    var rating: Int
    var comment: String
    /// True when review was written from a real completed booking.
    var verified: Bool? = nil
    var createdAt: Date
}
