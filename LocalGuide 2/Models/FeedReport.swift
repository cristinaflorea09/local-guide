import Foundation

struct FeedReport: Codable, Identifiable {
    enum TargetType: String, Codable {
        case post, comment
    }

    let id: String
    var targetType: TargetType
    var targetId: String
    var postId: String? = nil
    var reporterId: String
    var reason: String
    var createdAt: Date
    var resolved: Bool = false
    var resolvedAt: Date? = nil
    var resolvedBy: String? = nil
}
