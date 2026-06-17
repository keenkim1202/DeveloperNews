import Testing
import Foundation
@testable import DeveloperNews

// Exercises FeedPost dependency injection: AppState is built from the mock and
// the canned feed-post flow is observed through the injected service.
@MainActor
@Suite struct FeedPostServiceTests {
    private func makeStory() -> FeedPostStory {
        FeedPostStory(
            url: "https://example.com/story",
            title: "A Story",
            sourceName: "Source",
            sourceCategory: .article,
            topics: [.ios],
            thumbnailURL: nil)
    }

    private func makePost(
        id: String = "post-1",
        authorId: String = "author-1",
    ) -> FeedPost {
        FeedPost(
            id: id,
            authorId: authorId,
            authorName: "Author",
            authorEmoji: nil,
            comment: "Great read",
            story: makeStory(),
            likeCount: 0,
            likedBy: [],
            commentCount: 0,
            createdAt: .now,
            updatedAt: nil)
    }

    @Test func appStateExposesInjectedFeedPostService() {
        let feedPost = MockFeedPostServicing()
        let state = VMFixtures.makeAppState(feedPost: feedPost)

        #expect(state.feedPostService as? MockFeedPostServicing === feedPost)
    }

    @Test func fetchRecentPostsReturnsCannedPosts() async {
        let feedPost = MockFeedPostServicing()
        feedPost.recentPosts = [makePost(id: "a"), makePost(id: "b")]
        let state = VMFixtures.makeAppState(feedPost: feedPost)

        let posts = await state.feedPostService.fetchRecentPosts(limit: 20)

        #expect(posts.map(\.id) == ["a", "b"])
        #expect(feedPost.fetchedRecentLimits == [20])
    }

    @Test func updateAndDeleteAreRecorded() async {
        let feedPost = MockFeedPostServicing()
        let state = VMFixtures.makeAppState(feedPost: feedPost)
        let post = makePost()

        await state.feedPostService.toggleLike(post, userId: "user-9")
        await state.feedPostService.updatePost(post, comment: "Edited", editorId: post.authorId)
        await state.feedPostService.deletePost(post)

        #expect(feedPost.toggledLikes.first?.userId == "user-9")
        #expect(feedPost.updatedPosts.first?.comment == "Edited")
        #expect(feedPost.deletedPostIds == [post.id])
    }
}
