import FirebaseAuth
import Foundation
@testable import DeveloperNews

@MainActor
final class MockCommentServicing: CommentServicing {
    var comments: [CommunityComment] = []
    var errorMessage: String?

    private(set) var listeningPostId: String?
    private(set) var didStopListening = false
    private(set) var addedComments: [(text: String, parentId: String?, postAuthorId: String)] = []
    private(set) var reportedComments: [(commentId: String, reporterId: String, reason: String)] = []
    private(set) var toggledCommentLikes: [(commentId: String, userId: String)] = []
    private(set) var deletedComments: [(commentId: String, postAuthorId: String)] = []

    func startListening(postId: String) {
        listeningPostId = postId
    }

    func stopListening() {
        didStopListening = true
    }

    func addComment(
        postId: String,
        postAuthorId: String,
        text: String,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
        parentCommentId: String?,
    ) async {
        addedComments.append((
            text: text,
            parentId: parentCommentId,
            postAuthorId: postAuthorId))
    }

    func deleteComment(_ comment: CommunityComment, postAuthorId: String) async {
        deletedComments.append((commentId: comment.id, postAuthorId: postAuthorId))
        comments.removeAll { $0.id == comment.id }
    }

    func toggleCommentLike(
        _ comment: CommunityComment,
        userId: String,
    ) async {
        toggledCommentLikes.append((commentId: comment.id, userId: userId))
    }

    func reportComment(
        _ comment: CommunityComment,
        reporterId: String,
        reason: String,
    ) async {
        reportedComments.append((commentId: comment.id, reporterId: reporterId, reason: reason))
    }
}
