import Testing
import Foundation
@testable import DeveloperNews

extension StubbedSourceClientTests {
@MainActor
@Suite struct DevToSourceClientTests {
    // Clear any stubs a prior test registered on the shared protocol before each
    // test, mirroring the original per-test teardown reset.
    init() {
        StubURLProtocol.reset()
    }

    @Test func mapsArticlesIntoContentItems() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://dev.to/api/articles",
            json: """
            [
                {
                    "id": 1,
                    "title": "Building with React",
                    "description": "A frontend guide",
                    "url": "https://dev.to/a/react",
                    "cover_image": "https://dev.to/img/react.png",
                    "published_at": "2024-01-01T00:00:00Z",
                    "tag_list": ["react", "webdev"],
                    "public_reactions_count": 50,
                    "comments_count": 10,
                    "user": {"name": "Jane"}
                },
                {
                    "id": 2,
                    "title": "Rust services",
                    "description": "Backend with Rust",
                    "url": "https://dev.to/a/rust",
                    "cover_image": null,
                    "published_at": "2024-02-02T00:00:00Z",
                    "tag_list": ["rust", "backend"],
                    "public_reactions_count": 5,
                    "comments_count": 2,
                    "user": {"name": "John"}
                }
            ]
            """)

        let client = DevToSourceClient(session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [])

        #expect(items.count == 2)

        let react = try #require(items.first { $0.title == "Building with React" })
        #expect(react.sourceName == "DEV.to")
        #expect(react.sourceCategory == .article)
        #expect(react.kind == .article)
        #expect(react.url.absoluteString == "https://dev.to/a/react")
        #expect(react.authorName == "Jane")
        #expect(react.thumbnailURL?.absoluteString == "https://dev.to/img/react.png")
        #expect(react.topics.contains(.web))

        let rust = try #require(items.first { $0.title == "Rust services" })
        #expect(rust.thumbnailURL == nil)
        #expect(rust.topics.contains(.backend))
    }

    @Test func emptyResponseProducesNoItems() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://dev.to/api/articles",
            json: "[]")

        let client = DevToSourceClient(session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [.ios])

        #expect(items.isEmpty)
    }
}
}
