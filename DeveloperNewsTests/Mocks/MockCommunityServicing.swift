import FirebaseAuth
import Foundation
@testable import DeveloperNews

@MainActor
final class MockCommunityServicing: CommunityServicing {
    var posts: [CommunityPost] = []
    var isLoading = false
    var errorMessage: String?
    var authorEmojiCache: [String: String] = [:]

    var hasReportedResult = false

    private(set) var didStartListening = false
    private(set) var didStopListening = false

    func post(id: CommunityPost.ID) -> CommunityPost? {
        posts.first { $0.id == id }
    }

    func startListening() {
        didStartListening = true
    }

    func refresh() async {
    }

    func stopListening() {
        didStopListening = true
    }

    func createPost(
        title: String,
        description: String,
        link: String?,
        topics: [Topic],
        author: FirebaseAuth.User,
        authorDisplayName: String,
    ) async {
    }

    func updatePost(
        _ post: CommunityPost,
        title: String,
        description: String,
        link: String?,
        topics: [Topic],
        editorId: String,
    ) async {
    }

    func deletePost(_ post: CommunityPost) async {
        posts.removeAll { $0.id == post.id }
    }

    func reportPost(
        _ post: CommunityPost,
        reporterId: String,
        reason: String,
    ) async {
    }

    func hasReportedPost(
        _ postId: String,
        reporterId: String,
    ) async -> Bool {
        hasReportedResult
    }

    func authorEmoji(for authorId: String) -> String? {
        authorEmojiCache[authorId]
    }

    func filteredPosts(excludingUserIds blockedIds: Set<String>) -> [CommunityPost] {
        posts.filter { !blockedIds.contains($0.authorId) }
    }

    func deleteUserContent(uid: String) async throws {
    }

    func toggleLike(
        _ post: CommunityPost,
        userId: String,
    ) async {
    }
}
