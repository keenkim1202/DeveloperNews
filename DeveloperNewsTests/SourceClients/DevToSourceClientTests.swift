import XCTest
@testable import DeveloperNews

@MainActor
final class DevToSourceClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testMapsArticlesIntoContentItems() async throws {
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

        XCTAssertEqual(items.count, 2)

        let react = try XCTUnwrap(items.first { $0.title == "Building with React" })
        XCTAssertEqual(react.sourceName, "DEV.to")
        XCTAssertEqual(react.sourceCategory, .article)
        XCTAssertEqual(react.kind, .article)
        XCTAssertEqual(react.url.absoluteString, "https://dev.to/a/react")
        XCTAssertEqual(react.authorName, "Jane")
        XCTAssertEqual(react.thumbnailURL?.absoluteString, "https://dev.to/img/react.png")
        XCTAssertTrue(react.topics.contains(.web))

        let rust = try XCTUnwrap(items.first { $0.title == "Rust services" })
        XCTAssertNil(rust.thumbnailURL)
        XCTAssertTrue(rust.topics.contains(.backend))
    }

    func testEmptyResponseProducesNoItems() async throws {
        StubURLProtocol.register(
            urlPrefix: "https://dev.to/api/articles",
            json: "[]")

        let client = DevToSourceClient(session: StubURLProtocol.makeSession())
        let items = try await client.fetchItems(selectedTopics: [.ios])

        XCTAssertTrue(items.isEmpty)
    }
}
