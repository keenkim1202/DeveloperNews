import XCTest
@testable import DeveloperNews

// A configurable in-test source client that either returns canned items or
// throws, used to drive CompositeContentSourceClient aggregation behavior.
private struct StubSourceClient: ContentSourceClient {
    let items: [ContentItem]
    let shouldFail: Bool

    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        if shouldFail {
            throw URLError(.timedOut)
        }
        return items
    }
}

@MainActor
final class CompositeContentSourceClientTests: XCTestCase {
    private func makeItem(
        title: String,
        sourceName: String,
        urlString: String,
    ) -> ContentItem {
        ContentItem(
            id: UUID(),
            kind: .article,
            title: title,
            summary: "summary",
            sourceName: sourceName,
            sourceCategory: .article,
            authorName: nil,
            url: URL(string: urlString)!,
            publishedAt: .now,
            topics: [.ios],
            trendScore: 70)
    }

    func testAggregatesItemsFromMultipleSources() async throws {
        let a = StubSourceClient(
            items: [makeItem(title: "Alpha", sourceName: "A", urlString: "https://a.com/1")],
            shouldFail: false)
        let b = StubSourceClient(
            items: [makeItem(title: "Beta", sourceName: "B", urlString: "https://b.com/1")],
            shouldFail: false)

        let composite = CompositeContentSourceClient(namedClients: [
            .init(name: "Source A", client: a),
            .init(name: "Source B", client: b)
        ])

        let result = await composite.fetchItemsWithStatus(selectedTopics: [])

        XCTAssertEqual(result.totalSourceCount, 2)
        XCTAssertTrue(result.failedSourceNames.isEmpty)
        XCTAssertEqual(Set(result.items.map(\.title)), ["Alpha", "Beta"])
    }

    func testReportsFailedSourceNames() async throws {
        let ok = StubSourceClient(
            items: [makeItem(title: "Good", sourceName: "Good", urlString: "https://good.com/1")],
            shouldFail: false)
        let bad = StubSourceClient(items: [], shouldFail: true)

        let composite = CompositeContentSourceClient(namedClients: [
            .init(name: "Healthy", client: ok),
            .init(name: "Broken", client: bad)
        ])

        let result = await composite.fetchItemsWithStatus(selectedTopics: [])

        XCTAssertEqual(result.totalSourceCount, 2)
        XCTAssertEqual(result.failedSourceNames, ["Broken"])
        XCTAssertEqual(result.items.map(\.title), ["Good"])
    }

    func testDeduplicatesItemsSharingURL() async throws {
        let a = StubSourceClient(
            items: [makeItem(title: "Shared", sourceName: "A", urlString: "https://dup.com/x")],
            shouldFail: false)
        let b = StubSourceClient(
            items: [makeItem(title: "Shared", sourceName: "B", urlString: "https://dup.com/x")],
            shouldFail: false)

        let composite = CompositeContentSourceClient(namedClients: [
            .init(name: "A", client: a),
            .init(name: "B", client: b)
        ])

        let result = await composite.fetchItemsWithStatus(selectedTopics: [])

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.title, "Shared")
    }

    func testAllSourcesFailingYieldsEmptyItemsAndAllNames() async throws {
        let bad1 = StubSourceClient(items: [], shouldFail: true)
        let bad2 = StubSourceClient(items: [], shouldFail: true)

        let composite = CompositeContentSourceClient(namedClients: [
            .init(name: "One", client: bad1),
            .init(name: "Two", client: bad2)
        ])

        let result = await composite.fetchItemsWithStatus(selectedTopics: [])

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(Set(result.failedSourceNames), ["One", "Two"])
        XCTAssertEqual(result.totalSourceCount, 2)
    }
}
