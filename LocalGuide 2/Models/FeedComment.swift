import Foundation

struct FeedComment: Codable, Identifiable {
    let id: String
    var postId: String
    var authorId: String
    var authorName: String? = nil
    var text: String
    var likeCount: Int = 0
    var reportCount: Int = 0
    var isHidden: Bool = false
    var createdAt: Date
}
