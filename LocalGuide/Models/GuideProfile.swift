import Foundation

struct GuideProfile: Codable, Identifiable {
    let id: String
    var displayName: String
    var country: String
    var city: String
    var languages: [String]
    var bio: String
    var photoURL: String?

    // Compliance
    var attestationURL: String?

    // Ratings
    var ratingAvg: Double
    var ratingCount: Int
    var createdAt: Date
}
