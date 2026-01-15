import Foundation

enum BookingStatus: String, Codable {
    case pendingPayment
    case confirmed
    case cancelled
    case failed
}

struct Booking: Codable, Identifiable {
    let id: String
    var tourId: String
    var slotId: String
    var guideId: String
    var userId: String
    var date: Date
    var peopleCount: Int
    var totalPrice: Double
    var currency: String
    var status: BookingStatus
    var paymentIntentId: String?
    var createdAt: Date
}
