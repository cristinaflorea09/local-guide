import Foundation

final class BookingService {
    static let shared = BookingService()
    private init() {}

    /// Reserves an availability slot atomically on the server and creates a booking in `pendingPayment`.
    /// Returns bookingId.
    func reserveSlotAndCreateBooking(
        slotId: String,
        tour: Tour,
        date: Date,
        peopleCount: Int,
        total: Double
    ) async throws -> String {
        let fn = FirebaseManager.shared.functions.httpsCallable("reserveSlotAndCreateBooking")
        let cents = Int((total * 100.0).rounded())
        let res = try await fn.call([
            "slotId": slotId,
            "tourId": tour.id,
            "guideId": tour.guideId,
            "date": date.timeIntervalSince1970,
            "peopleCount": peopleCount,
            "amount": cents,
            "currency": AppConfig.stripeCurrency
        ])
        guard let dict = res.data as? [String: Any],
              let bookingId = dict["bookingId"] as? String else {
            throw NSError(domain: "BookingService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid reserve response"])
        }
        return bookingId
    }
}
