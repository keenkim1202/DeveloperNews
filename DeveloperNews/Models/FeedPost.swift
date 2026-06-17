import Foundation

struct FeedPost: Identifiable, Hashable, Sendable {
    let id: String
    let authorId: String
    let authorName: String
    let authorEmoji: String?
    let comment: String
    let story: FeedPostStory
    let likeCount: Int
    let likedBy: Set<String>
    let commentCount: Int
    let createdAt: Date
    let updatedAt: Date?
}

struct FeedPostStory: Hashable, Sendable {
    let url: String
    let title: String
    let sourceName: String
    let sourceCategory: SourceCategory
    let topics: [Topic]
    let thumbnailURL: String?

    var storyURL: URL? {
        URL(string: url)
    }
}
