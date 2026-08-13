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

    @Test func loadBioUsesOwnProfileBioWhenOwnProfile() async {
        let auth = MockAuthServicing(userId: "author-1")
        let profile = MockProfileServicing()
        profile.profileBio = "My own bio"
        // A summary is seeded too to prove the own-profile path is preferred.
        profile.userSummaries = [
            UserSummary(id: "author-1", displayName: "Me", emoji: nil, bio: "Fetched bio"),
        ]
        let appState = VMFixtures.makeAppState(auth: auth, profile: profile)
        let viewModel = UserProfileViewModel(appState: appState, authorId: "author-1")

        await viewModel.loadBio()

        #expect(viewModel.authorBio == "My own bio")
    }

    @Test func loadBioUsesFetchedSummaryBioForOtherUser() async {
        let auth = MockAuthServicing(userId: "viewer")
        let profile = MockProfileServicing()
        profile.profileBio = "Viewer bio"
        profile.userSummaries = [
            UserSummary(id: "author-1", displayName: "Ada", emoji: nil, bio: "Ada's bio"),
        ]
        let appState = VMFixtures.makeAppState(auth: auth, profile: profile)
        let viewModel = UserProfileViewModel(appState: appState, authorId: "author-1")

        await viewModel.loadBio()

        #expect(viewModel.authorBio == "Ada's bio")
    }

    @Test("표시 이름이 빈 문자열이면 이름이 없는 것으로 취급한다")
    func treatsEmptyDisplayNameAsMissing() async {
        let auth = MockAuthServicing(userId: "viewer")
        let profile = MockProfileServicing()
        // Firestore hands back an empty string for a user who never set a name.
        profile.userSummaries = [
            UserSummary(id: "author-1", displayName: "", emoji: "", bio: nil),
        ]
        let appState = VMFixtures.makeAppState(auth: auth, profile: profile)
        let viewModel = UserProfileViewModel(appState: appState, authorId: "author-1")

        await viewModel.loadBio()

        #expect(viewModel.authorName == nil)
        #expect(viewModel.authorEmoji == nil)
    }

    @Test("프로필을 불러오기 전에는 불러왔다고 표시하지 않는다")
    func doesNotReportProfileLoadedBeforeFetch() async {
        let auth = MockAuthServicing(userId: "viewer")
        let profile = MockProfileServicing()
        profile.userSummaries = [
            UserSummary(id: "author-1", displayName: "Ada", emoji: nil, bio: nil),
        ]
        let appState = VMFixtures.makeAppState(auth: auth, profile: profile)
        let viewModel = UserProfileViewModel(appState: appState, authorId: "author-1")

        #expect(viewModel.hasLoadedProfile == false)

        await viewModel.loadBio()

        #expect(viewModel.hasLoadedProfile)
    }
}
