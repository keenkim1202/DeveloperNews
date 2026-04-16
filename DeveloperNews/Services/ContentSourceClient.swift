import Foundation

enum AppIdentity {
    static let userAgent = "DeveloperNews/1.0 (https://github.com/keenkim1202/DeveloperNews)"
}

struct SourceFetchResult {
    let items: [ContentItem]
    let failedSourceNames: [String]
    let totalSourceCount: Int
}

protocol ContentSourceClient {
    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem]
    func fetchItemsWithStatus(selectedTopics: Set<Topic>) async -> SourceFetchResult
}

extension ContentSourceClient {
    func fetchItemsWithStatus(selectedTopics: Set<Topic>) async -> SourceFetchResult {
        do {
            let items = try await fetchItems(selectedTopics: selectedTopics)
            return SourceFetchResult(items: items, failedSourceNames: [], totalSourceCount: 1)
        }
        catch {
            return SourceFetchResult(items: [], failedSourceNames: [], totalSourceCount: 1)
        }
    }
}

struct MockContentSourceClient: ContentSourceClient {
    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        try await Task.sleep(for: .milliseconds(150))
        return SampleData.items
    }
}

struct CompositeContentSourceClient: ContentSourceClient {
    struct NamedClient {
        let name: String
        let client: any ContentSourceClient
    }

    private static let sourceTrustBonus: [String: Int] = [
        "GitHub Blog": 5,
        "Swift with Majid": 4,
        "Mozilla Hacks": 3,
        "Cloudflare Blog": 3,
        "InfoQ": 2,
        "Hacker News": 2
    ]

    let namedClients: [NamedClient]

    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        await fetchItemsWithStatus(selectedTopics: selectedTopics).items
    }

    func fetchItemsWithStatus(selectedTopics: Set<Topic>) async -> SourceFetchResult {
        let outcomes = await withTaskGroup(of: (String, [ContentItem]?).self) { group in
            for named in namedClients {
                group.addTask {
                    do {
                        let items = try await named.client.fetchItems(selectedTopics: selectedTopics)
                        return (named.name, items)
                    }
                    catch {
                        return (named.name, nil)
                    }
                }
            }

            var results: [(String, [ContentItem]?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        var collectedItems: [ContentItem] = []
        var failedSourceNames: [String] = []
        for (name, maybeItems) in outcomes {
            if let items = maybeItems {
                collectedItems.append(contentsOf: items)
            }
            else {
                failedSourceNames.append(name)
            }
        }

        if collectedItems.isEmpty {
            return SourceFetchResult(
                items: [],
                failedSourceNames: failedSourceNames,
                totalSourceCount: namedClients.count)
        }

        let weighted = collectedItems.map(applyingSourceTrust)
        let normalized = normalizingScoresPerSource(weighted)
        let dedup = deduplicatedItems(from: normalized)
        return SourceFetchResult(
            items: dedup,
            failedSourceNames: failedSourceNames,
            totalSourceCount: namedClients.count)
    }

    private func normalizingScoresPerSource(_ items: [ContentItem]) -> [ContentItem] {
        let groups = Dictionary(grouping: items) { $0.sourceName }
        var result: [ContentItem] = []
        result.reserveCapacity(items.count)

        for (_, group) in groups {
            let sorted = group.sorted { $0.trendScore > $1.trendScore }
            let count = sorted.count
            for (rank, item) in sorted.enumerated() {
                let score: Int
                if count <= 1 {
                    score = 100
                }
                else {
                    score = 60 + Int((40.0 * Double(count - rank - 1) / Double(count - 1)).rounded())
                }
                result.append(
                    ContentItem(
                        id: item.id,
                        kind: item.kind,
                        title: item.title,
                        summary: item.summary,
                        sourceName: item.sourceName,
                        sourceCategory: item.sourceCategory,
                        authorName: item.authorName,
                        url: item.url,
                        publishedAt: item.publishedAt,
                        topics: item.topics,
                        trendScore: score,
                        thumbnailURL: item.thumbnailURL,
                        engagement: item.engagement))
            }
        }

        return result
    }

    private func applyingSourceTrust(_ item: ContentItem) -> ContentItem {
        let bonus = Self.sourceTrustBonus[item.sourceName] ?? 0
        guard bonus != 0 else {
            return item
        }

        return ContentItem(
            id: item.id,
            kind: item.kind,
            title: item.title,
            summary: item.summary,
            sourceName: item.sourceName,
            sourceCategory: item.sourceCategory,
            authorName: item.authorName,
            url: item.url,
            publishedAt: item.publishedAt,
            topics: item.topics,
            trendScore: min(100, item.trendScore + bonus),
            thumbnailURL: item.thumbnailURL,
            engagement: item.engagement)
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
        let thumbnail = primary.thumbnailURL ?? group.lazy.compactMap(\.thumbnailURL).first
        let engagement = primary.engagement ?? group.lazy.compactMap(\.engagement).first

        return ContentItem(
            id: primary.id,
            kind: primary.kind,
            title: primary.title,
            summary: primary.summary,
            sourceName: primary.sourceName,
            sourceCategory: primary.sourceCategory,
            authorName: primary.authorName,
            url: primary.url,
            publishedAt: primary.publishedAt,
            topics: unionedTopics,
            trendScore: min(100, primary.trendScore + mentionBoost),
            thumbnailURL: thumbnail,
            engagement: engagement)
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
