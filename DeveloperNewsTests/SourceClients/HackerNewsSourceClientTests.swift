import Testing
import Foundation
@testable import DeveloperNews

extension StubbedSourceClientTests {
@MainActor
@Suite struct HackerNewsSourceClientTests {
    // Clear any stubs a prior test registered on the shared protocol before each
    // test, mirroring the original per-test teardown reset.
    init() {
        StubURLProtocol.reset()
    }

    @Test func mapsTopStoryIntoContentItem() async throws {
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

        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.title == "A SwiftUI deep dive")
        #expect(item.sourceName == "Hacker News")
        #expect(item.sourceCategory == .hackerNews)
        #expect(item.kind == .discussion)
        #expect(item.url.absoluteString == "https://example.com/swiftui")
        #expect(item.authorName == "author1")
        #expect(item.engagement?.reactionCount == 200)
        #expect(item.engagement?.commentCount == 42)
        // "swiftui" keyword should map to the ios topic.
        #expect(item.topics.contains(.ios))
    }

    @Test func skipsNonStoryTypeAndMissingURL() async throws {
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

        #expect(items.isEmpty)
    }
}
}
