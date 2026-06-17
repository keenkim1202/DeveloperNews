import Testing
import Foundation
@testable import DeveloperNews

// Exercises real app code through @testable import to prove the host/@testable
// linkage works: constructs a ContentItem value type and checks pure logic.
// MainActor-isolated because the app target compiles with MainActor default
// isolation, so its value types and properties are main-actor bound.
@MainActor
@Suite struct ContentItemTests {
    private func makeItem(urlString: String) -> ContentItem {
        ContentItem(
            id: UUID(),
            kind: .article,
            title: "Hello",
            summary: "World",
            sourceName: "Test",
            sourceCategory: .article,
            authorName: nil,
            url: URL(string: urlString)!,
            publishedAt: .now,
            topics: [.ios],
            trendScore: 0)
    }

    @Test func hasExternalLinkForHTTPS() {
        let item = makeItem(urlString: "https://example.com/post")
        #expect(item.hasExternalLink)
    }

    @Test func hasExternalLinkFalseForNonWebScheme() {
        let item = makeItem(urlString: "devnews://internal/path")
        #expect(!item.hasExternalLink)
    }

    @Test func topicSymbolName() {
        #expect(Topic.ios.symbolName == "iphone")
    }
}
