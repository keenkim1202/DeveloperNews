import XCTest
@testable import DeveloperNews

@MainActor
final class RedditSourceClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testMapsListingIntoContentItems() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://www.reddit.com/r/swift.json",
            json: """
            {
                "data": {
                    "children": [
                        {
                            "data": {
                                "title": "SwiftUI tips",
                                "url": "https://example.com/swiftui-tips",
                                "selftext": "",
                                "score": 300,
                                "num_comments": 25,
                                "created_utc": 1700000000,
                                "is_self": false,
                                "over_18": false,
                                "spoiler": false,
                                "stickied": false,
                                "locked": false,
                                "quarantine": false,
                                "thumbnail": "default"
                            }
                        },
                        {
                            "data": {
                                "title": "NSFW post",
                                "url": "https://example.com/nsfw",
                                "score": 10,
                                "num_comments": 1,
                                "created_utc": 1700000000,
                                "is_self": false,
                                "over_18": true,
                                "spoiler": false,
                                "stickied": false,
                                "locked": false,
                                "quarantine": false,
                                "thumbnail": "nsfw"
                            }
                        },
                        {
                            "data": {
                                "title": "Self post should be skipped",
                                "url": "https://www.reddit.com/r/swift/comments/abc",
                                "selftext": "text",
                                "score": 5,
                                "num_comments": 0,
                                "created_utc": 1700000000,
                                "is_self": true,
                                "over_18": false,
                                "spoiler": false,
                                "stickied": false,
                                "locked": false,
                                "quarantine": false,
                                "thumbnail": "self"
                            }
                        }
                    ]
                }
            }
            """)

        let feeds = [RedditFeedDefinition(subreddit: "swift", defaultTopics: [.ios])]
        let client = RedditSourceClient(
            feeds: feeds,
            session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [])

        // Only the first post is eligible: the NSFW post is filtered, and the
        // self post is dropped because it has no external link.
        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.title, "SwiftUI tips")
        XCTAssertEqual(item.sourceName, "Reddit")
        XCTAssertEqual(item.sourceCategory, .reddit)
        XCTAssertEqual(item.kind, .discussion)
        XCTAssertEqual(item.authorName, "r/swift")
        XCTAssertEqual(item.url.absoluteString, "https://example.com/swiftui-tips")
        XCTAssertEqual(item.engagement?.reactionCount, 300)
        XCTAssertEqual(item.engagement?.commentCount, 25)
        // Fallback topics from the feed definition apply.
        XCTAssertTrue(item.topics.contains(.ios))
        XCTAssertNil(item.thumbnailURL)
    }

    func testRespectsMaxItemsPerFeed() async throws {
        let children = (0..<5).map { index in
            """
            {
                "data": {
                    "title": "Post \(index)",
                    "url": "https://example.com/post\(index)",
                    "score": 10,
                    "num_comments": 1,
                    "created_utc": 1700000000,
                    "is_self": false,
                    "over_18": false,
                    "spoiler": false,
                    "stickied": false,
                    "locked": false,
                    "quarantine": false,
                    "thumbnail": "default"
                }
            }
            """
        }.joined(separator: ",")

        StubURLProtocol.register(
            urlPrefix: "https://www.reddit.com/r/programming.json",
            json: "{\"data\": {\"children\": [\(children)]}}")

        let feeds = [RedditFeedDefinition(subreddit: "programming", defaultTopics: [.backend])]
        let client = RedditSourceClient(
            feeds: feeds,
            session: StubURLProtocol.makeSession(),
            maxItemsPerFeed: 2)
        let items = try await client.fetchItems(selectedTopics: [])

        XCTAssertEqual(items.count, 2)
    }
}
