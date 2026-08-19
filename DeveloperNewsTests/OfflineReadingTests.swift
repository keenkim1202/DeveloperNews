import Foundation
import Testing
@testable import DeveloperNews

// Capturing is tied to bookmarking: saved articles are kept, everything else is
// refused, and unsaving gives the space back.
@MainActor
@Suite struct OfflineReadingTests {
    private func makeState() -> AppState {
        VMFixtures.makeAppState()
    }

    @Test func anUnsavedArticleIsNotCaptured() {
        let state = makeState()
        let item = VMFixtures.makeItem()

        state.captureOfflineArticle(item, paragraphs: ["body"])

        #expect(!state.hasOfflineArticle(for: item.url))
    }

    @Test func aSavedArticleIsCaptured() {
        let state = makeState()
        let item = VMFixtures.makeItem()
        state.addSavedItem(item)

        state.captureOfflineArticle(item, paragraphs: ["body"])

        #expect(state.hasOfflineArticle(for: item.url))
        #expect(state.offlineArticle(for: item.url)?.title == item.title)
    }

    @Test func unsavingThroughToggleDropsTheCapture() {
        let state = makeState()
        let item = VMFixtures.makeItem()
        state.toggleSaved(item)
        state.captureOfflineArticle(item, paragraphs: ["body"])
        #expect(state.hasOfflineArticle(for: item.url))

        state.toggleSaved(item)

        #expect(!state.isSaved(item))
        #expect(!state.hasOfflineArticle(for: item.url))
    }

    @Test func removingABookmarkDirectlyDropsTheCapture() {
        let state = makeState()
        let item = VMFixtures.makeItem()
        state.addSavedItem(item)
        state.captureOfflineArticle(item, paragraphs: ["body"])

        state.removeSavedItem(at: item.url)

        #expect(!state.hasOfflineArticle(for: item.url))
    }
}
