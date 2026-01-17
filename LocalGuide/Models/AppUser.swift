import Foundation

struct AppUser: Identifiable, Codable {
    var id: String
    var email: String?

    // Profile
    var fullName: String
    var dateOfBirth: Date?
    var country: String
    var city: String
    var preferredLanguageCode: String

    // Role & entitlements
    var role: UserRole
    var subscriptionPlan: SubscriptionPlan   // free_ads or premium
    var disabled: Bool

    // Optional avatar
    var photoURL: String?

    var createdAt: Date
    var guideApproved: Bool
    var guideProfileCreated: Bool

}

enum SubscriptionPlan: String, Codable {
    case freeAds = "free_ads"
    case premium = "premium"
}
