import Foundation

enum AvailabilityStatus: String, Codable {
    case open
    case reserved
    case closed
}

struct AvailabilitySlot: Codable, Identifiable {
    let id: String
    var guideId: String
    /// "tour" or "experience" (Stage 6+).
    var listingType: String? = nil
    /// tourId or experienceId (Stage 6+).
    var listingId: String? = nil
    /// capacity for this slot (defaults to listing maxPeople).
    var capacity: Int? = nil
    /// reserved flag from backend.
    var isReserved: Bool? = nil
    var reservedBy: String? = nil
    var reservedCount: Int? = nil
    var start: Date
    var end: Date
    var status: AvailabilityStatus
    var bookingId: String?
    var createdAt: Date
}
