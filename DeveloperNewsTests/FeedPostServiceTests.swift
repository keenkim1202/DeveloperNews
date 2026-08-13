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

    @Test("id와 일치하는 게시물을 반환한다") func postByIdReturnsMatchingPost() async {
        let feedPost = MockFeedPostServicing()
        feedPost.recentPosts = [makePost(id: "a"), makePost(id: "b")]
        let state = VMFixtures.makeAppState(feedPost: feedPost)

        let post = await state.feedPostService.post(id: "b")

        #expect(post?.id == "b")
        #expect(feedPost.requestedPostIds == ["b"])
    }

    @Test("문서가 없으면 nil을 반환한다") func postByIdReturnsNilWhenMissing() async {
        let feedPost = MockFeedPostServicing()
        feedPost.recentPosts = [makePost(id: "a")]
        let state = VMFixtures.makeAppState(feedPost: feedPost)

        let post = await state.feedPostService.post(id: "missing")

        // Only the nil return is checked. That a missing document leaves
        // `errorMessage` alone is a contract of the live Firestore path, and the
        // mock has no code that could set it — asserting it here would pass no
        // matter what `FeedPostService` did.
        #expect(post == nil)
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
