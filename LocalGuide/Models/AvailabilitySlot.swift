import Foundation

enum AvailabilityStatus: String, Codable {
    case open
    case reserved
    case closed
}

struct AvailabilitySlot: Codable, Identifiable {
    let id: String
    var guideId: String
    var start: Date
    var end: Date
    var status: AvailabilityStatus
    var bookingId: String?
    var createdAt: Date
}
