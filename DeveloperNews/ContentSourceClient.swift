import Foundation

protocol ContentSourceClient {
    func fetchItems() async throws -> [ContentItem]
}

struct MockContentSourceClient: ContentSourceClient {
    func fetchItems() async throws -> [ContentItem] {
        try await Task.sleep(for: .milliseconds(150))
        return SampleData.items
    }
}

struct CompositeContentSourceClient: ContentSourceClient {
    let clients: [any ContentSourceClient]
    let fallbackClient: any ContentSourceClient

    func fetchItems() async throws -> [ContentItem] {
        var collectedItems: [ContentItem] = []

        for client in clients {
            if let items = try? await client.fetchItems(), !items.isEmpty {
                collectedItems.append(contentsOf: items)
            }
        }

        if collectedItems.isEmpty {
            return try await fallbackClient.fetchItems()
        }

        return deduplicatedItems(from: collectedItems)
    }

    private func deduplicatedItems(from items: [ContentItem]) -> [ContentItem] {
        var seenURLs: Set<String> = []
        var deduplicated: [ContentItem] = []

        for item in items.sorted(by: sortItemsDescending) {
            let urlKey = item.url.absoluteString
            if seenURLs.contains(urlKey) {
                continue
            }

            seenURLs.insert(urlKey)
            deduplicated.append(item)
        }

        return deduplicated
    }

    private func sortItemsDescending(lhs: ContentItem, rhs: ContentItem) -> Bool {
        if lhs.trendScore == rhs.trendScore {
            return lhs.publishedAt > rhs.publishedAt
        }

        return lhs.trendScore > rhs.trendScore
    }
}
