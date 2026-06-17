import FirebaseAuth
import Foundation
@testable import DeveloperNews

@MainActor
final class MockCommentServicing: CommentServicing {
    var comments: [CommunityComment] = []
    var errorMessage: String?

    private(set) var listeningPostId: String?
    private(set) var didStopListening = false

    func startListening(postId: String) {
        listeningPostId = postId
    }

    func stopListening() {
        didStopListening = true
    }

    func addComment(
        postId: String,
        text: String,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
    ) async {
    }

    func deleteComment(_ comment: CommunityComment) async {
        comments.removeAll { $0.id == comment.id }
    }
}
