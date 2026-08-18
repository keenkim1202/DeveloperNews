import Foundation

/// One entry in a user's activity inbox: something another user did to their
/// content. Written by the actor's client into the recipient's subcollection,
/// so the recipient learns about a reaction without polling their own posts.
///
/// Only `actorId` is stored. The actor's name and emoji are resolved when the
/// inbox is read, because the inbox is a signed-in-only screen that may read
/// `/users`, and because a name copied onto every activity would go stale the
/// moment its owner renamed themselves.
struct Activity: Identifiable, Hashable, Sendable {
    let id: String
    let kind: ActivityKind
    let actorId: String
    let target: ActivityTarget?
    /// The comment the activity is about: the one just written for a comment
    /// or reply, the one liked for a comment like. Nil for a post like or a
    /// follow, which are about no comment.
    let commentId: String?
    /// For a reply, the comment being answered. Stored so the security rules
    /// can check that the recipient is the person actually replied to, rather
    /// than taking the writer's word for it.
    let parentCommentId: String?
    /// Short excerpt of what the actor wrote, or of the content they reacted
    /// to, so the row reads on its own without fetching the post.
    let preview: String
    let createdAt: Date
    let isRead: Bool
}

enum ActivityKind: String, Sendable, CaseIterable {
    case postLike
    case postComment
    case commentReply
    case commentLike
    case follow
}

/// The post an activity points at, paired with the collection holding it.
///
/// Only the two collections that have a detail route are representable. Story
/// comments live under `storyEngagement`, whose document id is a hash of the
/// story URL and so cannot be turned back into a destination; those actions
/// record no activity rather than producing a row that goes nowhere.
enum ActivityTarget: Hashable, Sendable {
    case feedPost(FeedPost.ID)
    case communityPost(CommunityPost.ID)

    /// Firestore collection name, also the value persisted on the document.
    var collectionName: String {
        switch self {
        case .feedPost:
            "feedPosts"
        case .communityPost:
            "posts"
        }
    }

    var postId: String {
        switch self {
        case let .feedPost(id):
            id
        case let .communityPost(id):
            id
        }
    }

    init?(
        collectionName: String,
        postId: String,
    ) {
        switch collectionName {
        case "feedPosts":
            self = .feedPost(postId)
        case "posts":
            self = .communityPost(postId)
        default:
            return nil
        }
    }
}
