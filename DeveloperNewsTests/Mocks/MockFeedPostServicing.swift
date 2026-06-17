import FirebaseAuth
import Foundation
@testable import DeveloperNews

@MainActor
final class MockFeedPostServicing: FeedPostServicing {
    var errorMessage: String?

    var recentPosts: [FeedPost] = []
    var authorPosts: [FeedPost] = []
    var authorsPosts: [FeedPost] = []

    private(set) var createdComments: [String] = []
    private(set) var toggledLikes: [(postId: String, userId: String)] = []
    private(set) var updatedPosts: [(postId: String, comment: String)] = []
    private(set) var deletedPostIds: [String] = []
    private(set) var reportedPosts: [(postId: String, reporterId: String, reason: String)] = []
    private(set) var fetchedRecentLimits: [Int] = []
    private(set) var fetchedAuthorIds: [String] = []
    private(set) var fetchedAuthorBatches: [[String]] = []

    func createPost(
        comment: String,
        story: FeedPostStory,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
    ) async {
        createdComments.append(comment)
    }

    func toggleLike(
        _ post: FeedPost,
        userId: String,
    ) async {
        toggledLikes.append((post.id, userId))
    }

    func updatePost(
        _ post: FeedPost,
        comment: String,
        editorId: String,
    ) async {
        updatedPosts.append((post.id, comment))
    }

    func deletePost(_ post: FeedPost) async {
        deletedPostIds.append(post.id)
    }

    func reportPost(
        _ post: FeedPost,
        reporterId: String,
        reason: String,
    ) async {
        reportedPosts.append((post.id, reporterId, reason))
    }

    func fetchRecentPosts(limit: Int) async -> [FeedPost] {
        fetchedRecentLimits.append(limit)
        return recentPosts
    }

    func fetchPosts(byAuthor authorId: String) async -> [FeedPost] {
        fetchedAuthorIds.append(authorId)
        return authorPosts
    }

    func fetchPosts(byAuthors authorIds: [String]) async -> [FeedPost] {
        fetchedAuthorBatches.append(authorIds)
        return authorsPosts
    }
}
