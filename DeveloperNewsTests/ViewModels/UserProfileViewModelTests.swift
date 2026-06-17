import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct UserProfileViewModelTests {
    @Test func loadFeedPostsLoadsAuthorPostsSortedDescending() async {
        let feedPost = MockFeedPostServicing()
        let older = VMFixtures.makeFeedPost(
            id: "older",
            authorId: "author-1",
            createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = VMFixtures.makeFeedPost(
            id: "newer",
            authorId: "author-1",
            createdAt: Date(timeIntervalSince1970: 2_000))
        // Seed out of order so we can prove the VM sorts by createdAt desc.
        feedPost.authorPosts = [older, newer]
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        let viewModel = UserProfileViewModel(appState: appState, authorId: "author-1")

        await viewModel.loadFeedPosts()

        #expect(viewModel.authorFeedPosts.map(\.id) == ["newer", "older"])
        #expect(feedPost.fetchedAuthorIds == ["author-1"])
    }

    @Test func loadFeedPostsExcludesOtherAuthors() async {
        let feedPost = MockFeedPostServicing()
        // The service is queried by author, so only this author's posts come back.
        let mine = VMFixtures.makeFeedPost(id: "mine", authorId: "author-1")
        feedPost.authorPosts = [mine]
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        let viewModel = UserProfileViewModel(appState: appState, authorId: "author-1")

        await viewModel.loadFeedPosts()

        #expect(viewModel.authorFeedPosts.allSatisfy { $0.authorId == "author-1" })
        #expect(viewModel.authorFeedPosts.map(\.id) == ["mine"])
    }

    @Test func loadFeedPostsSurfacesServiceError() async {
        let feedPost = MockFeedPostServicing()
        feedPost.errorMessage = "Failed to load posts"
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        let viewModel = UserProfileViewModel(appState: appState, authorId: "author-1")

        await viewModel.loadFeedPosts()

        #expect(appState.toastMessage == "Failed to load posts")
    }
}
