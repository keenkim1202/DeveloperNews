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
        let byURL = collapseExactURLDuplicates(items)
        let groups = Dictionary(grouping: byURL) { titleKey(for: $0.title) }

        let merged = groups.values.map { group -> ContentItem in
            guard group.count > 1 else {
                return group[0]
            }
            return mergedItem(from: group)
        }

        return merged.sorted(by: sortItemsDescending)
    }

    private func collapseExactURLDuplicates(_ items: [ContentItem]) -> [ContentItem] {
        var byURL: [String: ContentItem] = [:]
        for item in items {
            let key = item.url.absoluteString
            if let existing = byURL[key] {
                byURL[key] = item.trendScore > existing.trendScore ? item : existing
            }
            else {
                byURL[key] = item
            }
        }
        return Array(byURL.values)
    }

    private func mergedItem(from group: [ContentItem]) -> ContentItem {
        let primary = group.max(by: { $0.trendScore < $1.trendScore }) ?? group[0]
        let mentionBoost = (group.count - 1) * 4
        let unionedTopics = Array(Set(group.flatMap(\.topics)))

        return ContentItem(
            id: primary.id,
            kind: primary.kind,
            title: primary.title,
            summary: primary.summary,
            sourceName: primary.sourceName,
            authorName: primary.authorName,
            url: primary.url,
            publishedAt: primary.publishedAt,
            topics: unionedTopics,
            trendScore: min(100, primary.trendScore + mentionBoost)
        )
    }

    private func titleKey(for title: String) -> String {
        let lowered = title.lowercased()
        let scalars = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    private func sortItemsDescending(lhs: ContentItem, rhs: ContentItem) -> Bool {
        if lhs.trendScore == rhs.trendScore {
            return lhs.publishedAt > rhs.publishedAt
        }

        return lhs.trendScore > rhs.trendScore
    }
}
