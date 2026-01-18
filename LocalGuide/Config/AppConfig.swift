import Foundation

enum AppConfig {
    static let appName = "LocalGuide"
    // StoreKit subscription product IDs (set these to your App Store Connect IDs)
    static let subscriptionProductIds: Set<String> = [
        "localGuideMembership"
    ]
    // Booking currency for Stripe
    static let googleMapsAPIKey: String = "AIzaSyD94r5pcpfIgQrQpwPiCLrYkmsWIPHHJx8"

    /// Base URL for your deployed Cloud Functions (Stripe seller subscriptions).
    /// Example: "https://us-central1-YOUR_PROJECT.cloudfunctions.net/"
    // RO + EU seller tiers: Cloud Functions picks RON for country==Romania, EUR otherwise.
    static let stripeFunctionsBaseURL: String = "https://europe-west1-localguide-ca222.cloudfunctions.net"

    static let stripeCurrency = "eur"
}
