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

    // The captured text is on the device for offline reading either way. Without
    // searching it, an article is findable only by remembering its title.
    @Test func searchFilterMatchesCapturedArticleText() async {
        let appState = VMFixtures.makeAppState()
        let item = VMFixtures.makeItem(title: "Weekly roundup", summary: "x", sourceName: "Blog")
        seed(appState, [item])
        appState.captureOfflineArticle(item, paragraphs: ["A note on structured concurrency."])
        let vm = SavedViewModel(appState: appState)

        vm.searchQuery = "structured concurrency"
        #expect(vm.matchingArticleItems.map(\.title) == ["Weekly roundup"])

        vm.searchQuery = "nothing in this article"
        #expect(vm.matchingArticleItems.isEmpty)
    }

    // A capture is replaced when the page is read again, so the text searched
    // has to be the current one.
    @Test func searchFilterUsesTheLatestCapture() async {
        let appState = VMFixtures.makeAppState()
        let item = VMFixtures.makeItem(title: "Weekly roundup", summary: "x", sourceName: "Blog")
        seed(appState, [item])
        appState.captureOfflineArticle(item, paragraphs: ["First capture about actors."])
        let vm = SavedViewModel(appState: appState)

        vm.searchQuery = "actors"
        #expect(vm.matchingArticleItems.count == 1)

        appState.captureOfflineArticle(item, paragraphs: ["Rewritten, now about macros."])
        #expect(vm.matchingArticleItems.isEmpty)

        vm.searchQuery = "macros"
        #expect(vm.matchingArticleItems.count == 1)
    }

    // Only the head of a capture is indexed. Without a bound, a full library of
    // long articles would be joined and lowercased on the main actor the first
    // time a query matched none of them.
    @Test func searchFilterOnlyReachesTheIndexedHeadOfACapture() async {
        let appState = VMFixtures.makeAppState()
        let item = VMFixtures.makeItem(title: "Long read", summary: "x", sourceName: "Blog")
        seed(appState, [item])
        let filler = Array(repeating: String(repeating: "a", count: 1000), count: 30)
        appState.captureOfflineArticle(item, paragraphs: filler + ["buried needle"])
        let vm = SavedViewModel(appState: appState)

        vm.searchQuery = "buried needle"
        #expect(vm.matchingArticleItems.isEmpty)

        vm.searchQuery = "aaa"
        #expect(vm.matchingArticleItems.count == 1)
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
