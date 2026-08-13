import FirebaseAuth
import Foundation

@MainActor
protocol FeedPostServicing {
    var errorMessage: String? { get }

    // Bumped whenever a post is created so feeds can detect they are stale
    // and reload, even when the create happened from another screen.
    var creationToken: Int { get }

    func createPost(
        comment: String,
        story: FeedPostStory,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
    ) async

    func toggleLike(
        _ post: FeedPost,
        userId: String,
    ) async

    func updatePost(
        _ post: FeedPost,
        comment: String,
        editorId: String,
    ) async

    func deletePost(_ post: FeedPost) async

    func reportPost(
        _ post: FeedPost,
        reporterId: String,
        reason: String,
    ) async

    // Resolves an id back into a post, e.g. when a navigation destination
    // carries only the id. Returns nil once the post is gone, and throws when
    // the read itself fails — the caller has to tell those apart.
    func post(id: FeedPost.ID) async throws -> FeedPost?

    func fetchRecentPosts(limit: Int) async -> [FeedPost]

    func fetchPosts(byAuthor authorId: String) async -> [FeedPost]

    func fetchPosts(byAuthors authorIds: [String]) async -> [FeedPost]
}
