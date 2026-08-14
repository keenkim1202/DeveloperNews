import FirebaseAuth
import Foundation

@MainActor
protocol CommunityServicing {
    var posts: [CommunityPost] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var authorEmojiCache: [String: String] { get }

    /// Looks the post up in the loaded window only. Returns nil for a post
    /// that exists but is older than that window, so a caller that must not
    /// mistake "not loaded" for "deleted" needs `fetchPost(id:)`.
    func post(id: CommunityPost.ID) -> CommunityPost?

    /// Reads the single post document for `id`.
    ///
    /// Returns nil only when the document is genuinely absent. A read that
    /// fails throws instead, so a network drop is not reported as a deletion.
    func fetchPost(id: CommunityPost.ID) async throws -> CommunityPost?

    func startListening()
    func refresh() async
    func stopListening()

    func createPost(
        title: String,
        description: String,
        link: String?,
        topics: [Topic],
        author: FirebaseAuth.User,
        authorDisplayName: String,
    ) async

    func updatePost(
        _ post: CommunityPost,
        title: String,
        description: String,
        link: String?,
        topics: [Topic],
        editorId: String,
    ) async

    func deletePost(_ post: CommunityPost) async

    func reportPost(
        _ post: CommunityPost,
        reporterId: String,
        reason: String,
    ) async

    func hasReportedPost(
        _ postId: String,
        reporterId: String,
    ) async -> Bool

    func authorEmoji(for authorId: String) -> String?

    func filteredPosts(excludingUserIds blockedIds: Set<String>) -> [CommunityPost]

    func deleteUserContent(uid: String) async throws

    func toggleLike(
        _ post: CommunityPost,
        userId: String,
    ) async
}
