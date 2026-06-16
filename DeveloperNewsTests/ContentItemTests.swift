import XCTest
@testable import DeveloperNews

// Exercises real app code through @testable import to prove the host/@testable
// linkage works: constructs a ContentItem value type and checks pure logic.
// MainActor-isolated because the app target compiles with MainActor default
// isolation, so its value types and properties are main-actor bound.
@MainActor
final class ContentItemTests: XCTestCase {
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

    func testHasExternalLinkForHTTPS() {
        let item = makeItem(urlString: "https://example.com/post")
        XCTAssertTrue(item.hasExternalLink)
    }

    func testHasExternalLinkFalseForNonWebScheme() {
        let item = makeItem(urlString: "devnews://internal/path")
        XCTAssertFalse(item.hasExternalLink)
    }

    func testTopicSymbolName() {
        XCTAssertEqual(Topic.ios.symbolName, "iphone")
    }
}
