import XCTest
@testable import DeveloperNews

@MainActor
final class HackerNewsSourceClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testMapsTopStoryIntoContentItem() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://hacker-news.firebaseio.com/v0/topstories.json",
            json: "[101]")
        StubURLProtocol.register(
            urlPrefix: "https://hacker-news.firebaseio.com/v0/item/101.json",
            json: """
            {
                "type": "story",
                "title": "A SwiftUI deep dive",
                "url": "https://example.com/swiftui",
                "by": "author1",
                "score": 200,
                "time": 1700000000,
                "descendants": 42
            }
            """)

        let client = HackerNewsSourceClient(session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [.ios])

        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.title, "A SwiftUI deep dive")
        XCTAssertEqual(item.sourceName, "Hacker News")
        XCTAssertEqual(item.sourceCategory, .hackerNews)
        XCTAssertEqual(item.kind, .discussion)
        XCTAssertEqual(item.url.absoluteString, "https://example.com/swiftui")
        XCTAssertEqual(item.authorName, "author1")
        XCTAssertEqual(item.engagement?.reactionCount, 200)
        XCTAssertEqual(item.engagement?.commentCount, 42)
        // "swiftui" keyword should map to the ios topic.
        XCTAssertTrue(item.topics.contains(.ios))
    }

    func testSkipsNonStoryTypeAndMissingURL() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://hacker-news.firebaseio.com/v0/topstories.json",
            json: "[201, 202]")
        StubURLProtocol.register(
            urlPrefix: "https://hacker-news.firebaseio.com/v0/item/201.json",
            json: """
            {"type": "comment", "title": "not a story", "url": "https://x.com", "score": 1, "time": 1}
            """)
        StubURLProtocol.register(
            urlPrefix: "https://hacker-news.firebaseio.com/v0/item/202.json",
            json: """
            {"type": "story", "title": "no url story", "score": 5, "time": 2}
            """)

        let client = HackerNewsSourceClient(session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [.web, .ios])

        XCTAssertTrue(items.isEmpty)
    }
}
