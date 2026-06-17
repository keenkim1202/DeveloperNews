import Testing
import Foundation
@testable import DeveloperNews

extension StubbedSourceClientTests {
@MainActor
@Suite struct GitHubTrendingSourceClientTests {
    // Reset the process-wide search cache and any stubs a prior test registered
    // before each test, mirroring the original per-test setup/teardown resets.
    init() async {
        await GitHubTrendingSourceClient.resetCacheForTesting()
        StubURLProtocol.reset()
    }

    @Test func mapsSearchResultsIntoContentItems() async throws {
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

        let client = GitHubTrendingSourceClient(
            session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [])

        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.title == "owner/cool-swift")
        #expect(item.summary == "A SwiftUI toolkit")
        #expect(item.sourceName == "GitHub Trending")
        #expect(item.sourceCategory == .github)
        #expect(item.authorName == "owner")
        #expect(item.url.absoluteString == "https://github.com/owner/cool-swift")
        #expect(item.engagement?.reactionCount == 4000)
        #expect(item.engagement?.commentCount == 120)
        #expect(item.topics.contains(.ios))
    }

    @Test func deduplicatesReposBySameURL() async throws {
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
            session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [])

        #expect(items.count == 1)
        #expect(items[0].topics.contains(.backend))
    }
}
}
