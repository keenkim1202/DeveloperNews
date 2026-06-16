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
        text: String,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
    ) async

    func deleteComment(_ comment: CommunityComment) async
}
