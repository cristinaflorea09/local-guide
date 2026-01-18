import Foundation
import FirebaseFunctions

final class TripPlannerService {
    static let shared = TripPlannerService()
    private init() {}

    /// Calls the Cloud Function `generateTripPlan` and returns the plan dictionary.
    func generateTripPlan(
        country: String,
        city: String,
        startDate: Date,
        endDate: Date,
        interests: [String],
        budgetPerDay: Double?,
        pace: String?,
        groupSize: Int?,
        languageCode: String
    ) async throws -> (tripPlanId: String, plan: [String: Any]) {
        let fn = FirebaseManager.shared.functions.httpsCallable("generateTripPlan")
        // Use date-only ISO (YYYY-MM-DD). Cloud Functions often validate this strictly.
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let payload: [String: Any] = [
            "country": country,
            "city": city,
            "startDateISO": fmt.string(from: startDate),
            "endDateISO": fmt.string(from: endDate),
            "interests": interests,
            "budgetPerDay": budgetPerDay as Any,
            "pace": pace as Any,
            "groupSize": groupSize as Any,
            "languageCode": languageCode,
        ]

        let res = try await fn.call(payload)
        guard
            let dict = res.data as? [String: Any],
            let id = dict["tripPlanId"] as? String,
            let plan = dict["plan"] as? [String: Any]
        else {
            throw NSError(domain: "TripPlannerService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid trip plan response"])
        }
        return (id, plan)
    }
}
