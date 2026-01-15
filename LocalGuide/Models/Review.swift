import Foundation

struct Review: Codable, Identifiable {
    let id: String
    var tourId: String
    var guideId: String
    var userId: String
    var rating: Int
    var comment: String
    var createdAt: Date
}
