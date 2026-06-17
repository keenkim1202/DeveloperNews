import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct CommunityViewModelTests {
    @Test func filteredPostsExcludesBlockedAuthors() async {
        let community = MockCommunityServicing()
        community.posts = [
            VMFixtures.makePost(authorId: "ok", title: "Keep"),
            VMFixtures.makePost(authorId: "blocked", title: "Hide")
        ]
        let appState = VMFixtures.makeAppState(community: community)
        appState.blockedUserIds = ["blocked"]
        let vm = CommunityViewModel(appState: appState)

        let titles = vm.filteredPosts.map(\.title)
        #expect(titles == ["Keep"])
    }

    @Test func filteredPostsSearchMatchesTitleDescriptionAndAuthor() async {
        let community = MockCommunityServicing()
        community.posts = [
            VMFixtures.makePost(authorName: "Alice", title: "SwiftUI Tips", description: "x"),
            VMFixtures.makePost(authorName: "Bob", title: "Other", description: "concurrency notes"),
            VMFixtures.makePost(authorName: "Carol", title: "Z", description: "y")
        ]
        let appState = VMFixtures.makeAppState(community: community)
        let vm = CommunityViewModel(appState: appState)

        vm.searchQuery = "swiftui"
        #expect(vm.filteredPosts.map(\.title) == ["SwiftUI Tips"])

        vm.searchQuery = "concurrency"
        #expect(vm.filteredPosts.map(\.title) == ["Other"])

        vm.searchQuery = "carol"
        #expect(vm.filteredPosts.map(\.title) == ["Z"])
    }

    @Test func filteredPostsCombineSearchAndBlock() async {
        let community = MockCommunityServicing()
        community.posts = [
            VMFixtures.makePost(authorId: "ok", title: "Swift Alpha"),
            VMFixtures.makePost(authorId: "blocked", title: "Swift Beta"),
            VMFixtures.makePost(authorId: "ok", title: "Kotlin")
        ]
        let appState = VMFixtures.makeAppState(community: community)
        appState.blockedUserIds = ["blocked"]
        let vm = CommunityViewModel(appState: appState)

        vm.searchQuery = "swift"
        // "Swift Beta" is blocked, "Kotlin" fails search -> only "Swift Alpha".
        #expect(vm.filteredPosts.map(\.title) == ["Swift Alpha"])
    }

    @Test func emptyQueryReturnsAllNonBlockedPosts() async {
        let community = MockCommunityServicing()
        community.posts = [
            VMFixtures.makePost(authorId: "a"),
            VMFixtures.makePost(authorId: "b")
        ]
        let appState = VMFixtures.makeAppState(community: community)
        let vm = CommunityViewModel(appState: appState)

        #expect(vm.filteredPosts.count == 2)
        #expect(!vm.hasNoPosts)
    }
}
