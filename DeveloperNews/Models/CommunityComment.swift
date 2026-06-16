import Foundation

struct CommunityComment: Identifiable, Hashable, Sendable {
    let id: String
    let postId: String
    let authorId: String
    let authorName: String
    let authorEmoji: String?
    let text: String
    let createdAt: Date
}
