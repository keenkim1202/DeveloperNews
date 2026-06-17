import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct UserSearchViewModelTests {
    @Test func emptyQueryClearsResultsAndDoesNotSearch() async {
        let profile = MockProfileServicing()
        profile.searchResults = [UserSummary(id: "u1", displayName: "Ada", emoji: nil, bio: nil)]
        let appState = VMFixtures.makeAppState(profile: profile)
        let viewModel = UserSearchViewModel(appState: appState)
        viewModel.query = "   "

        await viewModel.search()

        #expect(viewModel.results.isEmpty)
        #expect(profile.searchedQueries.isEmpty)
    }

    @Test func nonEmptyQuerySearchesAndStoresResults() async {
        let profile = MockProfileServicing()
        let results = [
            UserSummary(id: "u1", displayName: "Ada", emoji: "👩‍💻", bio: nil),
            UserSummary(id: "u2", displayName: "Alan", emoji: nil, bio: nil),
        ]
        profile.searchResults = results
        let appState = VMFixtures.makeAppState(profile: profile)
        let viewModel = UserSearchViewModel(appState: appState)
        viewModel.query = "Al"

        await viewModel.search()

        #expect(viewModel.results == results)
        #expect(profile.searchedQueries == ["Al"])
    }

    @Test func isFollowingDelegatesToProfileService() async {
        let profile = MockProfileServicing()
        profile.followedUserIds = ["u1"]
        let appState = VMFixtures.makeAppState(profile: profile)
        let viewModel = UserSearchViewModel(appState: appState)

        #expect(viewModel.isFollowing("u1"))
        #expect(!viewModel.isFollowing("u2"))
    }

    @Test func toggleFollowDelegatesToProfileService() async {
        let profile = MockProfileServicing()
        let appState = VMFixtures.makeAppState(profile: profile)
        let viewModel = UserSearchViewModel(appState: appState)

        await viewModel.toggleFollow("u1")
        #expect(profile.followedUserIds.contains("u1"))

        await viewModel.toggleFollow("u1")
        #expect(!profile.followedUserIds.contains("u1"))
    }
}
