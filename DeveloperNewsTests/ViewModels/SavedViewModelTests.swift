import XCTest
@testable import DeveloperNews

@MainActor
final class SavedViewModelTests: XCTestCase {
    // Seeds saved items directly through AppState so the VM reads real store state.
    private func seed(
        _ appState: AppState,
        _ items: [ContentItem],
    ) {
        VMFixtures.resetState(appState)
        for item in items {
            appState.addSavedItem(item)
        }
    }

    func testAvailableTopicsReflectsUnionOfSavedItemTopics() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(topics: [.ios]),
            VMFixtures.makeItem(topics: [.web, .ai])
        ])
        let vm = SavedViewModel(appState: appState)

        let topics = vm.availableTopics
        XCTAssertTrue(topics.contains(.ios))
        XCTAssertTrue(topics.contains(.web))
        XCTAssertTrue(topics.contains(.ai))
        XCTAssertFalse(topics.contains(.android))

        await VMFixtures.drainPersistence()
    }

    func testSearchFilterMatchesTitleSummaryAndSource() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(title: "SwiftUI Layout", summary: "x", sourceName: "Blog"),
            VMFixtures.makeItem(title: "Kotlin", summary: "Coroutines guide", sourceName: "Blog"),
            VMFixtures.makeItem(title: "Rust", summary: "y", sourceName: "Mozilla Hacks")
        ])
        let vm = SavedViewModel(appState: appState)

        vm.searchQuery = "swiftui"
        XCTAssertEqual(vm.matchingArticleItems.count, 1)

        vm.searchQuery = "coroutines"
        XCTAssertEqual(vm.matchingArticleItems.count, 1)

        vm.searchQuery = "mozilla"
        XCTAssertEqual(vm.matchingArticleItems.count, 1)

        vm.searchQuery = "nomatch"
        XCTAssertTrue(vm.matchingArticleItems.isEmpty)

        await VMFixtures.drainPersistence()
    }

    func testTopicAndSearchFiltersCombine() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(title: "iOS Alpha", topics: [.ios]),
            VMFixtures.makeItem(title: "iOS Beta", topics: [.ios]),
            VMFixtures.makeItem(title: "Web Alpha", topics: [.web])
        ])
        let vm = SavedViewModel(appState: appState)

        vm.topicFilters = [.ios]
        XCTAssertEqual(vm.matchingArticleItems.count, 2)

        vm.searchQuery = "alpha"
        // Topic gate keeps iOS-only, search gate keeps "Alpha"-titled -> 1 result.
        XCTAssertEqual(vm.matchingArticleItems.count, 1)
        XCTAssertEqual(vm.matchingArticleItems.first?.title, "iOS Alpha")

        await VMFixtures.drainPersistence()
    }

    func testEmptyFiltersReturnAllSavedArticles() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(),
            VMFixtures.makeItem()
        ])
        let vm = SavedViewModel(appState: appState)

        XCTAssertEqual(vm.matchingArticleItems.count, 2)
        XCTAssertTrue(vm.hasAnyMatches)

        await VMFixtures.drainPersistence()
    }
}
