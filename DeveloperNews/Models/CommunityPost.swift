import Foundation

struct CommunityPost: Identifiable, Hashable, Sendable {
    let id: String
    let authorId: String
    let authorName: String
    let title: String
    let description: String
    let link: String?
    let topics: [Topic]
    let likeCount: Int
    let likedBy: Set<String>
    let commentCount: Int
    let createdAt: Date
    let updatedAt: Date?

    var hasLink: Bool {
        guard let link, !link.isEmpty else { return false }
        return URL(string: link) != nil
    }

    var linkURL: URL? {
        guard let link else { return nil }
        return URL(string: link)
    }
}
