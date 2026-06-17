import Foundation

// Story-level engagement: like and comment counts tied to an external story URL
// itself, independent of any feed post that quotes the same story. The document
// id is derived from the URL so every client converges on the same record.
struct StoryEngagement: Identifiable, Hashable, Sendable {
    let id: String
    let storyURL: String
    let likeCount: Int
    let likedBy: Set<String>
    let commentCount: Int
    let viewCount: Int

    nonisolated static func documentId(for storyURL: String) -> String {
        HashUtil.shortHash(storyURL)
    }
}
