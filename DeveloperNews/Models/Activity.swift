import Foundation

/// One entry in a reader's activity inbox, written by the actor's client into
/// the recipient's subcollection so nobody has to poll their own posts.
///
/// Only `actorId` is stored; the name and emoji are resolved when the inbox is
/// read. A name copied onto every row goes stale the moment its owner renames.
struct Activity: Identifiable, Hashable, Sendable {
    let id: String
    let kind: ActivityKind
    let actorId: String
    let target: ActivityTarget?
    /// The comment the activity is about: the one just written for a comment
    /// or reply, the one liked for a comment like. Nil for a post like or a
    /// follow, which are about no comment.
    let commentId: String?
    /// Identifies the story an activity on a story comment points at. A story
    /// is not a document anyone owns, so its title and URL are copied here —
    /// there is no post record to read them back from.
    let story: ActivityStory?
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

/// The story an activity on a story comment refers to.
///
/// The engagement document id is a hash of the URL and cannot be reversed, so
/// the URL itself is stored to rebuild a destination from.
struct ActivityStory: Hashable, Sendable {
    let url: String
    let title: String
}

/// What an activity points at, paired with the collection holding it.
///
/// A story carries the hashed engagement document id. Unlike the two post
/// cases it names nothing anybody owns, so only activities about a story's
/// comments can use it — a story itself has no author to notify.
enum ActivityTarget: Hashable, Sendable {
    case feedPost(FeedPost.ID)
    case communityPost(CommunityPost.ID)
    case story(String)

    /// Firestore collection name, also the value persisted on the document.
    var collectionName: String {
        switch self {
        case .feedPost:
            "feedPosts"
        case .communityPost:
            "posts"
        case .story:
            "storyEngagement"
        }
    }

    var postId: String {
        switch self {
        case let .feedPost(id):
            id
        case let .communityPost(id):
            id
        case let .story(id):
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
        case "storyEngagement":
            self = .story(postId)
        default:
            return nil
        }
    }
}

/// The pair the app icon's number is written from: which snapshot it came from
/// and what it counted.
struct BadgeSync: Equatable {
    let snapshot: Int
    let count: Int
}
