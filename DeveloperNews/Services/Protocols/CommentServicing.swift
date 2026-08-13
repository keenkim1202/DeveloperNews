import FirebaseAuth
import Foundation

@MainActor
protocol CommentServicing {
    var comments: [CommunityComment] { get }
    var errorMessage: String? { get }

    func startListening(postId: String)
    func stopListening()

    func addComment(
        postId: String,
        postAuthorId: String,
        text: String,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
        parentCommentId: String?,
    ) async

    func deleteComment(_ comment: CommunityComment) async

    func toggleCommentLike(
        _ comment: CommunityComment,
        userId: String,
    ) async

    func reportComment(
        _ comment: CommunityComment,
        reporterId: String,
        reason: String,
    ) async
}
