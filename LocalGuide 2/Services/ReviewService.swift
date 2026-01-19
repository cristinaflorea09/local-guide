import Foundation
import FirebaseFunctions

private struct ReviewServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

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

        do {
            _ = try await fn.call(payload)
        } catch {
            // Surface the actual backend error message instead of just "INTERNAL".
            let ns = error as NSError
            if ns.domain == FunctionsErrorDomain {
                if let details = ns.userInfo[FunctionsErrorDetailsKey] {
                    throw ReviewServiceError(message: String(describing: details))
                }
                if let msg = ns.userInfo[NSLocalizedDescriptionKey] as? String {
                    throw ReviewServiceError(message: msg)
                }
            }
            throw error
        }
    }
}
