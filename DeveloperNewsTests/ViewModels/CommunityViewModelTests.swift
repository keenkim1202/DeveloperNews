import XCTest
@testable import DeveloperNews

@MainActor
final class CommunityViewModelTests: XCTestCase {
    func testFilteredPostsExcludesBlockedAuthors() async {
        let community = MockCommunityServicing()
        community.posts = [
            VMFixtures.makePost(authorId: "ok", title: "Keep"),
            VMFixtures.makePost(authorId: "blocked", title: "Hide")
        ]
        let appState = VMFixtures.makeAppState(community: community)
        appState.blockedUserIds = ["blocked"]
        let vm = CommunityViewModel(appState: appState)

        let titles = vm.filteredPosts.map(\.title)
        XCTAssertEqual(titles, ["Keep"])
    }

    func testFilteredPostsSearchMatchesTitleDescriptionAndAuthor() async {
        let community = MockCommunityServicing()
        community.posts = [
            VMFixtures.makePost(authorName: "Alice", title: "SwiftUI Tips", description: "x"),
            VMFixtures.makePost(authorName: "Bob", title: "Other", description: "concurrency notes"),
            VMFixtures.makePost(authorName: "Carol", title: "Z", description: "y")
        ]
        let appState = VMFixtures.makeAppState(community: community)
        let vm = CommunityViewModel(appState: appState)

        vm.searchQuery = "swiftui"
        XCTAssertEqual(vm.filteredPosts.map(\.title), ["SwiftUI Tips"])

        vm.searchQuery = "concurrency"
        XCTAssertEqual(vm.filteredPosts.map(\.title), ["Other"])

        vm.searchQuery = "carol"
        XCTAssertEqual(vm.filteredPosts.map(\.title), ["Z"])
    }

    func testFilteredPostsCombineSearchAndBlock() async {
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
        XCTAssertEqual(vm.filteredPosts.map(\.title), ["Swift Alpha"])
    }

    func testEmptyQueryReturnsAllNonBlockedPosts() async {
        let community = MockCommunityServicing()
        community.posts = [
            VMFixtures.makePost(authorId: "a"),
            VMFixtures.makePost(authorId: "b")
        ]
        let appState = VMFixtures.makeAppState(community: community)
        let vm = CommunityViewModel(appState: appState)

        XCTAssertEqual(vm.filteredPosts.count, 2)
        XCTAssertFalse(vm.hasNoPosts)
    }
}
