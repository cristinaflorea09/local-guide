import Foundation
import StripePaymentSheet

final class StripeService {
    static let shared = StripeService()
    private init() {}

    // Fetch publishable key from Firestore config and set it on Stripe API client.
    func configureStripe() async throws {
        let pk = try await FirestoreService.shared.getStripePublishableKey()
        StripeAPI.defaultPublishableKey = pk
        Log.payments.info("Stripe configured")
    }

    // Calls Firebase Function to create PaymentIntent and returns client secret + intent id.
    func createPaymentIntent(amountCents: Int, currency: String, bookingId: String) async throws -> (clientSecret: String, paymentIntentId: String) {
        let fn = FirebaseManager.shared.functions.httpsCallable("createPaymentIntent")
        let res = try await fn.call([
            "amount": amountCents,
            "currency": currency,
            "bookingId": bookingId
        ])
        guard let dict = res.data as? [String: Any],
              let clientSecret = dict["clientSecret"] as? String,
              let paymentIntentId = dict["paymentIntentId"] as? String else {
            throw NSError(domain: "StripeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid function response"])
        }
        return (clientSecret, paymentIntentId)
    }
}
