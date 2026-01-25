import Foundation

struct ChatThread: Codable, Identifiable, Hashable {
    let id: String
    var userId: String
    var email: String
    var tourId: String?
    var lastMessage: String?
    var lastSenderId: String?
    var updatedAt: Date
    var createdAt: Date
}

