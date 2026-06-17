import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct SavedViewModelTests {
    // Seeds saved items directly through AppState so the VM reads real store state.
    private func seed(
        _ appState: AppState,
        _ items: [ContentItem],
    ) {
        for item in items {
            appState.addSavedItem(item)
        }
    }

    @Test func availableTopicsReflectsUnionOfSavedItemTopics() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(topics: [.ios]),
            VMFixtures.makeItem(topics: [.web, .ai])
        ])
        let vm = SavedViewModel(appState: appState)

        let topics = vm.availableTopics
        #expect(topics.contains(.ios))
        #expect(topics.contains(.web))
        #expect(topics.contains(.ai))
        #expect(!topics.contains(.android))
    }

    @Test func searchFilterMatchesTitleSummaryAndSource() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(title: "SwiftUI Layout", summary: "x", sourceName: "Blog"),
            VMFixtures.makeItem(title: "Kotlin", summary: "Coroutines guide", sourceName: "Blog"),
            VMFixtures.makeItem(title: "Rust", summary: "y", sourceName: "Mozilla Hacks")
        ])
        let vm = SavedViewModel(appState: appState)

        vm.searchQuery = "swiftui"
        #expect(vm.matchingArticleItems.count == 1)

        vm.searchQuery = "coroutines"
        #expect(vm.matchingArticleItems.count == 1)

        vm.searchQuery = "mozilla"
        #expect(vm.matchingArticleItems.count == 1)

        vm.searchQuery = "nomatch"
        #expect(vm.matchingArticleItems.isEmpty)
    }

    @Test func topicAndSearchFiltersCombine() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(title: "iOS Alpha", topics: [.ios]),
            VMFixtures.makeItem(title: "iOS Beta", topics: [.ios]),
            VMFixtures.makeItem(title: "Web Alpha", topics: [.web])
        ])
        let vm = SavedViewModel(appState: appState)

        vm.topicFilters = [.ios]
        #expect(vm.matchingArticleItems.count == 2)

        vm.searchQuery = "alpha"
        // Topic gate keeps iOS-only, search gate keeps "Alpha"-titled -> 1 result.
        #expect(vm.matchingArticleItems.count == 1)
        #expect(vm.matchingArticleItems.first?.title == "iOS Alpha")
    }

    @Test func emptyFiltersReturnAllSavedArticles() async {
        let appState = VMFixtures.makeAppState()
        seed(appState, [
            VMFixtures.makeItem(),
            VMFixtures.makeItem()
        ])
        let vm = SavedViewModel(appState: appState)

        #expect(vm.matchingArticleItems.count == 2)
        #expect(vm.hasAnyMatches)
    }
}
