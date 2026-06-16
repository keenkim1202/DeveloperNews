import FirebaseAuth
import Foundation

@MainActor
protocol CommunityServicing {
    var posts: [CommunityPost] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var authorEmojiCache: [String: String] { get }

    func post(id: CommunityPost.ID) -> CommunityPost?

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
