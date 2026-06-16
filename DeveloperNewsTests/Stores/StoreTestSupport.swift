import Foundation
@testable import DeveloperNews

// Note on PersistenceStore: it is intentionally not tested here. Its init
// hardcodes `UserDefaults(suiteName: "group.keen-onit.DeveloperNews")`, so a
// round-trip test would read and write the app group's shared defaults and
// pollute state that other tests and the running app observe. There is no seam
// to inject a throwaway UserDefaults suite without changing production code,
// which this task forbids. Cleanly testing its write/load round-trip would
// require a UserDefaults-injection refactor (e.g. `init(defaults:)`); until
// then it is skipped.

// Shared helpers for constructing stores directly in store unit tests.
@MainActor
enum StoreTestSupport {
    static func makeItem(
        urlString: String,
        kind: ContentItem.Kind = .article,
        sourceName: String = "Test",
        sourceCategory: SourceCategory = .article,
        topics: [Topic] = [.ios],
        trendScore: Int = 0,
        publishedAt: Date = .now,
    ) -> ContentItem {
        ContentItem(
            id: UUID(),
            kind: kind,
            title: "Title \(urlString)",
            summary: "Summary",
            sourceName: sourceName,
            sourceCategory: sourceCategory,
            authorName: nil,
            url: URL(string: urlString)!,
            publishedAt: publishedAt,
            topics: topics,
            trendScore: trendScore)
    }
}

// Content source client returning a fixed result for deterministic FeedStore tests.
final class FixedContentSourceClient: ContentSourceClient, @unchecked Sendable {
    private let result: SourceFetchResult
    private let delay: Duration

    init(
        items: [ContentItem],
        failedSourceNames: [String] = [],
        totalSourceCount: Int = 1,
        delay: Duration = .zero,
    ) {
        result = SourceFetchResult(
            items: items,
            failedSourceNames: failedSourceNames,
            totalSourceCount: totalSourceCount)
        self.delay = delay
    }

    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        result.items
    }

    func fetchItemsWithStatus(selectedTopics: Set<Topic>) async -> SourceFetchResult {
        if delay != .zero {
            try? await Task.sleep(for: delay)
        }
        return result
    }
}
