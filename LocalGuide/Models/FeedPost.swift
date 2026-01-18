import Foundation

/// Community feed post.
struct FeedPost: Codable, Identifiable {
    enum PostType: String, Codable, CaseIterable {
        case tip, photo, warning, newExperience
    }

    let id: String
    var authorId: String
    var authorName: String? = nil
    var authorRole: String? = nil
    var type: PostType
    var title: String
    var text: String
    var city: String? = nil
    var photoURL: String? = nil
    var likeCount: Int = 0
    var commentCount: Int = 0
    var reportCount: Int = 0
    var isHidden: Bool = false
    var createdAt: Date
}
