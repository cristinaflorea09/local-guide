import Foundation
import FirebaseAuth

/// Stripe seller-tier subscriptions via Cloud Functions.
///
/// Expects an HTTPS endpoint: `.../createSellerSubscriptionCheckout`
/// that verifies the Firebase ID token and returns `{ "url": "https://checkout.stripe.com/..." }`.
/// See `Functions/stripe-seller-subscriptions`.
final class StripeSellerSubscriptionService {
    static let shared = StripeSellerSubscriptionService()
    private init() {}

    struct CheckoutResponse: Decodable {
        let url: URL
    }

    func createCheckoutURL(tier: SellerTier, role: UserRole) async throws -> URL {
        guard let base = URL(string: AppConfig.stripeFunctionsBaseURL), !AppConfig.stripeFunctionsBaseURL.isEmpty else {
            throw NSError(domain: "StripeSellerSubscriptionService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing AppConfig.stripeFunctionsBaseURL"]) 
        }
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "StripeSellerSubscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]) 
        }

        let idToken = try await user.getIDToken()

        let endpoint = base.appendingPathComponent("createSellerSubscriptionCheckout")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let payload: [String: String] = [
            "tier": tier.rawValue,
            "role": role.rawValue
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "StripeSellerSubscriptionService", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return try JSONDecoder().decode(CheckoutResponse.self, from: data).url
    }

func createBillingPortalURL() async throws -> URL {
    guard let base = URL(string: AppConfig.stripeFunctionsBaseURL) else {
        throw NSError(domain: "StripeSellerSubscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing AppConfig.stripeFunctionsBaseURL"])
    }
    guard let token = try await Auth.auth().currentUser?.getIDToken() else {
        throw NSError(domain: "StripeSellerSubscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
    }

    var req = URLRequest(url: base.appendingPathComponent("createBillingPortal"))
    req.httpMethod = "POST"
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: [:], options: [])

    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let msg = String(data: data, encoding: .utf8) ?? "Unknown server error"
        throw NSError(domain: "StripeSellerSubscriptionService", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    return try JSONDecoder().decode(CheckoutResponse.self, from: data).url
}

}
