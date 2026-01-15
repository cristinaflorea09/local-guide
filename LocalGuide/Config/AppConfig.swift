import Foundation

enum AppConfig {
    static let appName = "LocalGuide"
    // StoreKit subscription product IDs (set these to your App Store Connect IDs)
    static let subscriptionProductIds: Set<String> = [
        "localGuideMembership"
    ]
    // Booking currency for Stripe
    static let stripeCurrency = "eur"
}
