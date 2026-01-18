import Foundation

/// Review submission uses a callable Cloud Function so we can:
/// - ensure user actually booked
/// - prevent duplicates per booking
/// - update aggregates (avg + count) safely
final class ReviewService {
    static let shared = ReviewService()
    private init() {}

    /// Submit a review for the booking's listing and provider.
    func submitReview(booking: Booking, userId: String, rating: Int, comment: String) async throws {
        let clamped = max(1, min(5, rating))
        let fn = FirebaseManager.shared.functions.httpsCallable("addReview")
        let payload: [String: Any] = [
            "bookingId": booking.id,
            "rating": clamped,
            "comment": comment,
            // Extra fields for backward/forward compatible backends.
            "listingType": booking.effectiveListingType,
            "listingId": booking.effectiveListingId,
            "providerId": booking.effectiveProviderId
        ]
        _ = try await fn.call(payload)
    }
}
