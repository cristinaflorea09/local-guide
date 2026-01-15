import Foundation

struct GuideProfile: Codable, Identifiable {
    let id: String
    var displayName: String
    var city: String
    var languages: [String]
    var bio: String
    var photoURL: String?
    var ratingAvg: Double
    var ratingCount: Int
    var createdAt: Date
}
