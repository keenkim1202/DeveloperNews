import FirebaseAuth
import Foundation

@MainActor
protocol FeedPostServicing {
    var errorMessage: String? { get }

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

    func fetchRecentPosts(limit: Int) async -> [FeedPost]

    func fetchPosts(byAuthor authorId: String) async -> [FeedPost]

    func fetchPosts(byAuthors authorIds: [String]) async -> [FeedPost]
}
