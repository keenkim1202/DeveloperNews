import XCTest
@testable import DeveloperNews

@MainActor
final class HomeViewModelTests: XCTestCase {
    // Seeds the feed via a stub content source + reload so feed-derived state
    // (personalizedItems, paged items) is populated.
    private func makeSeededAppState(_ items: [ContentItem]) async -> AppState {
        let appState = VMFixtures.makeAppState(
            contentSourceClient: StubContentSourceClient(items: items))
        // Empty selectedTopics makes personalizedItems return every seeded item
        // regardless of any topics carried over from persisted state.
        VMFixtures.resetState(appState)
        await appState.reload()
        return appState
    }

    func testShouldShowTopStoryFalseWhenFeedEmpty() async {
        let appState = await makeSeededAppState([])
        let vm = HomeViewModel(appState: appState)

        XCTAssertFalse(vm.shouldShowTopStory)
        XCTAssertNil(vm.topItem)

        await VMFixtures.drainPersistence()
    }

    func testTopItemIsFirstPersonalizedWhenNoSearch() async {
        let high = VMFixtures.makeItem(title: "Top", trendScore: 100)
        let low = VMFixtures.makeItem(title: "Low", trendScore: 1)
        let appState = await makeSeededAppState([low, high])
        let vm = HomeViewModel(appState: appState)

        XCTAssertTrue(vm.shouldShowTopStory)
        XCTAssertEqual(vm.topItem?.title, "Top")

        await VMFixtures.drainPersistence()
    }

    func testTopItemSuppressedDuringSearch() async {
        let appState = await makeSeededAppState([
            VMFixtures.makeItem(title: "Top", trendScore: 100)
        ])
        let vm = HomeViewModel(appState: appState)

        vm.searchQuery = "Top"
        XCTAssertNil(vm.topItem)

        await VMFixtures.drainPersistence()
    }

    func testArticlesExcludingTopStoryDropsTheTopItem() async {
        let top = VMFixtures.makeItem(title: "Top", trendScore: 100)
        let other = VMFixtures.makeItem(title: "Other", trendScore: 50)
        let appState = await makeSeededAppState([top, other])
        let vm = HomeViewModel(appState: appState)

        XCTAssertEqual(vm.topItem?.title, "Top")
        let remaining = vm.articlesExcludingTopStory.map(\.title)
        XCTAssertFalse(remaining.contains("Top"))
        XCTAssertTrue(remaining.contains("Other"))

        await VMFixtures.drainPersistence()
    }

    func testSearchFiltersArticles() async {
        let appState = await makeSeededAppState([
            VMFixtures.makeItem(title: "SwiftUI", trendScore: 10),
            VMFixtures.makeItem(title: "Kotlin", trendScore: 9)
        ])
        let vm = HomeViewModel(appState: appState)

        vm.searchQuery = "swiftui"
        let titles = vm.filteredArticleItems.map(\.title)
        XCTAssertEqual(titles, ["SwiftUI"])

        await VMFixtures.drainPersistence()
    }

    func testShouldShowTopStoryFalseWhenDismissedRecently() async {
        let appState = await makeSeededAppState([
            VMFixtures.makeItem(title: "Top", trendScore: 100)
        ])
        appState.topStoryDismissedAt = .now
        let vm = HomeViewModel(appState: appState)

        XCTAssertTrue(appState.isTopStoryHidden)
        XCTAssertFalse(vm.shouldShowTopStory)

        await VMFixtures.drainPersistence()
    }
}
