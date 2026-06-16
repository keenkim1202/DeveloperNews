import XCTest
@testable import DeveloperNews

@MainActor
final class GitHubTrendingSourceClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testMapsSearchResultsIntoContentItems() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://api.github.com/search/repositories",
            json: """
            {
                "items": [
                    {
                        "full_name": "owner/cool-swift",
                        "description": "A SwiftUI toolkit",
                        "html_url": "https://github.com/owner/cool-swift",
                        "stargazers_count": 4000,
                        "forks_count": 120,
                        "language": "Swift",
                        "topics": ["swiftui", "ios"],
                        "pushed_at": "2024-03-03T00:00:00Z",
                        "owner": {"login": "owner"}
                    }
                ]
            }
            """)

        // Use a unique maxResults so the static search cache key does not collide
        // with other tests in this run.
        let client = GitHubTrendingSourceClient(
            session: StubURLProtocol.makeSession(),
            maxResults: 7001)
        let items = try await client.fetchItems(selectedTopics: [])

        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.title, "owner/cool-swift")
        XCTAssertEqual(item.summary, "A SwiftUI toolkit")
        XCTAssertEqual(item.sourceName, "GitHub Trending")
        XCTAssertEqual(item.sourceCategory, .github)
        XCTAssertEqual(item.authorName, "owner")
        XCTAssertEqual(item.url.absoluteString, "https://github.com/owner/cool-swift")
        XCTAssertEqual(item.engagement?.reactionCount, 4000)
        XCTAssertEqual(item.engagement?.commentCount, 120)
        XCTAssertTrue(item.topics.contains(.ios))
    }

    func testDeduplicatesReposBySameURL() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://api.github.com/search/repositories",
            json: """
            {
                "items": [
                    {
                        "full_name": "owner/dup",
                        "description": "first",
                        "html_url": "https://github.com/owner/dup",
                        "stargazers_count": 100,
                        "forks_count": 1,
                        "language": "Go",
                        "topics": [],
                        "pushed_at": "2024-03-03T00:00:00Z",
                        "owner": {"login": "owner"}
                    },
                    {
                        "full_name": "owner/dup",
                        "description": "second",
                        "html_url": "https://github.com/owner/dup",
                        "stargazers_count": 100,
                        "forks_count": 1,
                        "language": "Go",
                        "topics": [],
                        "pushed_at": "2024-03-03T00:00:00Z",
                        "owner": {"login": "owner"}
                    }
                ]
            }
            """)

        let client = GitHubTrendingSourceClient(
            session: StubURLProtocol.makeSession(),
            maxResults: 7002)
        let items = try await client.fetchItems(selectedTopics: [])

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].topics.contains(.backend))
    }
}
