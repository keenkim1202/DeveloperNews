import Testing
import Foundation
@testable import DeveloperNews

extension StubbedSourceClientTests {
@MainActor
@Suite struct RedditSourceClientTests {
    // Clear any stubs a prior test registered on the shared protocol before each
    // test, mirroring the original per-test teardown reset.
    init() {
        StubURLProtocol.reset()
    }

    @Test func mapsListingIntoContentItems() async throws {
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
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.title == "SwiftUI tips")
        #expect(item.sourceName == "Reddit")
        #expect(item.sourceCategory == .reddit)
        #expect(item.kind == .discussion)
        #expect(item.authorName == "r/swift")
        #expect(item.url.absoluteString == "https://example.com/swiftui-tips")
        #expect(item.engagement?.reactionCount == 300)
        #expect(item.engagement?.commentCount == 25)
        // Fallback topics from the feed definition apply.
        #expect(item.topics.contains(.ios))
        #expect(item.thumbnailURL == nil)
    }

    @Test func respectsMaxItemsPerFeed() async throws {
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

        #expect(items.count == 2)
    }
}
}
