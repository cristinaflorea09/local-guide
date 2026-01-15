import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: String
    var threadId: String
    var senderId: String
    var text: String
    var createdAt: Date
}
