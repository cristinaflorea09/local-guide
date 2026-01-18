import Foundation

final class BookingService {
    static let shared = BookingService()
    private init() {}

    /// Reserves an availability slot atomically on the server and creates a booking in `pendingPayment`.
    /// Returns bookingId.
    func reserveSlotAndCreateBooking(
        slot: AvailabilitySlot,
        tour: Tour,
        peopleCount: Int,
        total: Double,
        notes: String? = nil
    ) async throws -> String {

        let fn = FirebaseManager.shared.functions.httpsCallable("reserveSlotAndCreateBooking")
        let cents = Int((total * 100.0).rounded())

        let startISO = ISO8601DateFormatter().string(from: slot.start)
        let endISO = ISO8601DateFormatter().string(from: slot.end)

        let res = try await fn.call([
            "listingType": "tour",
            "listingId": tour.id,
            "providerId": tour.guideId,
            "slotId": slot.id,
            "tourId": tour.id,
            "guideId": tour.guideId,
            "startISO": startISO,
            "endISO": endISO,
            "peopleCount": peopleCount,
            "totalAmount": cents,
            "currency": AppConfig.stripeCurrency,
            "notes": notes as Any
        ])

        guard let dict = res.data as? [String: Any],
              let bookingId = dict["bookingId"] as? String else {
            throw NSError(domain: "BookingService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid reserve response"])
        }
        return bookingId
    }

    /// Experiences use the same booking + payment pipeline as tours.
    func reserveSlotAndCreateBooking(
        slot: AvailabilitySlot,
        experience: Experience,
        peopleCount: Int,
        total: Double,
        notes: String? = nil
    ) async throws -> String {
        let fn = FirebaseManager.shared.functions.httpsCallable("reserveSlotAndCreateBooking")
        let cents = Int((total * 100.0).rounded())

        let startISO = ISO8601DateFormatter().string(from: slot.start)
        let endISO = ISO8601DateFormatter().string(from: slot.end)

        // Backward compatibility: send tourId/guideId too (server can ignore for experiences).
        let res = try await fn.call([
            "listingType": "experience",
            "listingId": experience.id,
            "providerId": experience.hostId,
            "slotId": slot.id,
            "tourId": experience.id,
            "guideId": experience.hostId,
            "startISO": startISO,
            "endISO": endISO,
            "peopleCount": peopleCount,
            "totalAmount": cents,
            "currency": AppConfig.stripeCurrency,
            "notes": notes as Any
        ])

        guard let dict = res.data as? [String: Any],
              let bookingId = dict["bookingId"] as? String else {
            throw NSError(domain: "BookingService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid reserve response"])
        }
        return bookingId
    }
}
