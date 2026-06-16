import XCTest
@testable import DeveloperNews

@MainActor
final class RSSSourceClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testParsesRSSFeedIntoContentItems() async throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Test Feed</title>
                <item>
                    <title>Understanding async/await in Swift</title>
                    <description>A long enough description about concurrency in modern Swift code for parsing.</description>
                    <link>https://example.com/swift-async</link>
                    <author>Author One</author>
                    <pubDate>Wed, 03 Jan 2024 10:00:00 +0000</pubDate>
                </item>
                <item>
                    <title>React server components explained</title>
                    <description>An article covering web frontend rendering techniques in detail here.</description>
                    <link>https://example.com/react-rsc</link>
                    <pubDate>Thu, 04 Jan 2024 10:00:00 +0000</pubDate>
                </item>
            </channel>
        </rss>
        """

        StubURLProtocol.register(
            urlPrefix: "https://feeds.example.com/test",
            json: xml)

        let feeds = [
            RSSFeedDefinition(
                sourceName: "Test Source",
                feedURL: URL(static: "https://feeds.example.com/test"),
                defaultTopics: [.product])
        ]
        let client = RSSSourceClient(
            feeds: feeds,
            session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [])

        XCTAssertEqual(items.count, 2)

        let swiftItem = try XCTUnwrap(items.first { $0.title == "Understanding async/await in Swift" })
        XCTAssertEqual(swiftItem.sourceName, "Test Source")
        XCTAssertEqual(swiftItem.sourceCategory, .article)
        XCTAssertEqual(swiftItem.kind, .article)
        XCTAssertEqual(swiftItem.url.absoluteString, "https://example.com/swift-async")
        XCTAssertEqual(swiftItem.authorName, "Author One")
        // "swift" keyword maps to ios; the fallback product topic is preserved.
        XCTAssertTrue(swiftItem.topics.contains(.ios))
        XCTAssertTrue(swiftItem.topics.contains(.product))

        let reactItem = try XCTUnwrap(items.first { $0.title == "React server components explained" })
        XCTAssertNil(reactItem.authorName)
        XCTAssertTrue(reactItem.topics.contains(.web))
    }

    func testSkipsItemsMissingRequiredFields() async throws {
        // Items without a pubDate or link must be dropped by the parser.
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>No date</title>
                    <link>https://example.com/no-date</link>
                </item>
                <item>
                    <title>No link</title>
                    <pubDate>Wed, 03 Jan 2024 10:00:00 +0000</pubDate>
                </item>
            </channel>
        </rss>
        """

        StubURLProtocol.register(
            urlPrefix: "https://feeds.example.com/empty",
            json: xml)

        let feeds = [
            RSSFeedDefinition(
                sourceName: "Empty",
                feedURL: URL(static: "https://feeds.example.com/empty"),
                defaultTopics: [.web])
        ]
        let client = RSSSourceClient(
            feeds: feeds,
            session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [])

        XCTAssertTrue(items.isEmpty)
    }
}
