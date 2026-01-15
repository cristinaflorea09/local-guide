import Foundation

struct ChatThread: Codable, Identifiable {
    let id: String
    var userId: String
    var guideId: String
    var tourId: String?
    var lastMessage: String?
    var updatedAt: Date
    var createdAt: Date
}
