import Foundation
import Testing
@testable import DeveloperNews

@MainActor
@Suite struct OfflineArticleStoreTests {
    private func makeStore(
        onPersist: @escaping @MainActor ([OfflineArticle]) -> Void = { _ in },
    ) -> OfflineArticleStore {
        OfflineArticleStore(inputs: OfflineArticleStore.Inputs(persistOfflineArticles: onPersist))
    }

    private func url(_ path: String) -> URL {
        URL(string: "https://example.com/\(path)")!
    }

    @Test func storingMakesAnArticleReadableOffline() {
        let store = makeStore()

        store.store(url: url("a"), title: "A", sourceName: "S", paragraphs: ["one", "two"])

        #expect(store.hasArticle(for: url("a")))
        #expect(store.article(for: url("a"))?.paragraphs == ["one", "two"])
    }

    // Extraction picks up plenty of empty and whitespace-only blocks, and a
    // capture made entirely of those is not worth storing.
    @Test func blankParagraphsAreDroppedAndAnEmptyCaptureIsNotStored() {
        let store = makeStore()

        store.store(url: url("a"), title: "A", sourceName: "S", paragraphs: ["  ", "text", "\n"])
        store.store(url: url("b"), title: "B", sourceName: "S", paragraphs: ["", "   "])

        #expect(store.article(for: url("a"))?.paragraphs == ["text"])
        #expect(!store.hasArticle(for: url("b")))
    }

    @Test func recapturingReplacesTheEarlierText() {
        let store = makeStore()
        store.store(url: url("a"), title: "A", sourceName: "S", paragraphs: ["old"])

        store.store(url: url("a"), title: "A", sourceName: "S", paragraphs: ["new"])

        #expect(store.article(for: url("a"))?.paragraphs == ["new"])
    }

    @Test func removingAnArticleDropsItsText() {
        let store = makeStore()
        store.store(url: url("a"), title: "A", sourceName: "S", paragraphs: ["text"])

        store.removeArticle(for: url("a"))

        #expect(!store.hasArticle(for: url("a")))
    }

    @Test func aRunawayPageCannotFillTheStoreOnItsOwn() {
        let store = makeStore()
        let many = (0 ..< (OfflineArticleStore.maxParagraphs + 50)).map { "p\($0)" }

        store.store(url: url("a"), title: "A", sourceName: "S", paragraphs: many)

        #expect(store.article(for: url("a"))?.paragraphs.count == OfflineArticleStore.maxParagraphs)
    }

    @Test func theStoreIsCappedAndKeepsTheMostRecentCaptures() {
        let store = makeStore()
        for index in 0 ... OfflineArticleStore.maxArticles {
            store.store(
                url: url("\(index)"), title: "T", sourceName: "S", paragraphs: ["text"])
        }

        #expect(store.articlesByURL.count == OfflineArticleStore.maxArticles)
        #expect(store.hasArticle(for: url("\(OfflineArticleStore.maxArticles)")))
    }

    @Test func everyChangePersists() {
        var saved: [[OfflineArticle]] = []
        let store = makeStore { saved.append($0) }

        store.store(url: url("a"), title: "A", sourceName: "S", paragraphs: ["text"])
        store.removeArticle(for: url("a"))

        #expect(saved.count == 2)
        #expect(saved.last?.isEmpty == true)
    }

    @Test func seedingRestoresAPreviousSession() {
        let store = makeStore()
        let article = OfflineArticle(
            url: url("a"), title: "A", sourceName: "S",
            paragraphs: ["text"], capturedAt: .now)

        store.seedInitialState([article])

        #expect(store.article(for: url("a")) == article)
    }
}
