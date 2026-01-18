import Foundation
import FirebaseFunctions

/// Stripe Connect Express helpers.
///
/// This service assumes Cloud Functions exist:
/// - createConnectExpressOnboardingLink  (callable)
/// - requestPayoutAfterCompletion         (callable)
///
/// If you haven't deployed them yet, calls will fail with a readable error.
final class StripeConnectService {
    static let shared = StripeConnectService()
    private init() {}

    /// Returns onboarding URL for the current seller (guide/host).
    func createExpressOnboardingLink() async throws -> URL {
        let fn = FirebaseManager.shared.functions.httpsCallable("createConnectExpressOnboardingLink")
        let res = try await fn.call([:])
        guard let dict = res.data as? [String: Any],
              let urlStr = dict["url"] as? String,
              let url = URL(string: urlStr) else {
            throw NSError(domain: "StripeConnectService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid onboarding response"])
        }
        return url
    }

    /// Requests platform to release payout after a booking has completed.
    /// Backend should verify: booking.status == confirmed AND booking.endDate < now.
    func requestPayoutAfterCompletion(bookingId: String) async throws {
        let fn = FirebaseManager.shared.functions.httpsCallable("requestPayoutAfterCompletion")
        _ = try await fn.call(["bookingId": bookingId])
    }

    /// Lists recent Stripe payouts for the connected Express account.
    /// Backend must use Stripe Secret Key and query payouts on the connected account.
    func listPayouts(limit: Int = 30) async throws -> [StripePayout] {
        let fn = FirebaseManager.shared.functions.httpsCallable("listStripePayouts")
        let res = try await fn.call(["limit": limit])
        guard let dict = res.data as? [String: Any],
              let items = dict["payouts"] as? [[String: Any]] else {
            return []
        }

        func toDate(_ seconds: Any?) -> Date {
            if let n = seconds as? TimeInterval { return Date(timeIntervalSince1970: n) }
            if let n = seconds as? Double { return Date(timeIntervalSince1970: n) }
            if let n = seconds as? Int { return Date(timeIntervalSince1970: TimeInterval(n)) }
            return Date.distantPast
        }

        return items.compactMap { it in
            guard let id = it["id"] as? String,
                  let amount = it["amount"] as? Int,
                  let currency = it["currency"] as? String,
                  let status = it["status"] as? String else { return nil }
            let arrival = toDate(it["arrival_date"])
            return StripePayout(id: id, amount: amount, currency: currency, arrivalDate: arrival, status: status)
        }
        .sorted(by: { $0.arrivalDate > $1.arrivalDate })
    }
}
