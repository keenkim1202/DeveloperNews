import Foundation

struct RedditFeedDefinition {
    let subreddit: String
    let defaultTopics: [Topic]
}

struct RedditSourceClient: ContentSourceClient {
    let feeds: [RedditFeedDefinition]
    let session: URLSession
    let maxItemsPerFeed: Int

    init(
        feeds: [RedditFeedDefinition] = Self.defaultFeeds,
        session: URLSession = .shared,
        maxItemsPerFeed: Int = 8
    ) {
        self.feeds = feeds
        self.session = session
        self.maxItemsPerFeed = maxItemsPerFeed
    }

    func fetchItems() async throws -> [ContentItem] {
        var collectedItems: [ContentItem] = []

        for feed in feeds {
            if let items = try? await fetchItems(for: feed) {
                collectedItems.append(contentsOf: items)
            }
        }

        return collectedItems
    }

    private func fetchItems(for feed: RedditFeedDefinition) async throws -> [ContentItem] {
        let url = URL(string: "https://www.reddit.com/r/\(feed.subreddit).json")!
        var request = URLRequest(url: url)
        request.setValue("DeveloperNews/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(RedditListingResponse.self, from: data)

        return response.data.children.prefix(maxItemsPerFeed).compactMap { child in
            let post = child.data

            guard
                let urlString = post.url,
                let link = URL(string: urlString),
                !post.isSelf,
                !link.absoluteString.contains("reddit.com/r/")
            else {
                return nil
            }

            let publishedAt = Date(timeIntervalSince1970: post.createdUTC)
            let topics = inferredTopics(for: [post.title, post.selftext ?? "", urlString].joined(separator: " "), fallback: feed.defaultTopics)
            let summary = post.selftext?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalSummary = (summary?.isEmpty == false ? summary! : "Trending discussion from r/\(feed.subreddit).")

            return ContentItem(
                id: UUID(),
                kind: .discussion,
                title: post.title,
                summary: finalSummary,
                sourceName: "Reddit",
                authorName: "r/\(feed.subreddit)",
                url: link,
                publishedAt: publishedAt,
                topics: topics,
                trendScore: trendScore(score: post.score, commentCount: post.numComments, publishedAt: publishedAt)
            )
        }
    }

    private func inferredTopics(for text: String, fallback: [Topic]) -> [Topic] {
        let normalized = text.lowercased()
        var topics = Set(fallback)

        let rules: [(Topic, [String])] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["android", "kotlin", "jetpack", "gradle"]),
            (.web, ["web", "javascript", "typescript", "react", "browser"]),
            (.backend, ["server", "database", "backend", "api", "postgres"]),
            (.ai, ["ai", "llm", "model", "agent", "rag", "openai", "machine learning"]),
            (.devops, ["docker", "kubernetes", "deploy", "infrastructure", "ci"]),
            (.security, ["security", "auth", "token", "oauth", "vulnerability"]),
            (.product, ["product", "design", "startup", "team", "roadmap"])
        ]

        for (topic, keywords) in rules {
            if keywords.contains(where: normalized.contains) {
                topics.insert(topic)
            }
        }

        return Array(topics)
    }

    private func trendScore(score: Int, commentCount: Int, publishedAt: Date) -> Int {
        let hoursAgo = max(1, Int(Date().timeIntervalSince(publishedAt) / 3600))
        let engagementBoost = min(25, (score / 20) + (commentCount / 10))
        return max(58, min(98, 88 - hoursAgo + engagementBoost))
    }
}

extension RedditSourceClient {
    static let defaultFeeds: [RedditFeedDefinition] = [
        RedditFeedDefinition(subreddit: "programming", defaultTopics: [.web, .backend]),
        RedditFeedDefinition(subreddit: "webdev", defaultTopics: [.web, .product]),
        RedditFeedDefinition(subreddit: "iosprogramming", defaultTopics: [.ios]),
        RedditFeedDefinition(subreddit: "androiddev", defaultTopics: [.android]),
        RedditFeedDefinition(subreddit: "MachineLearning", defaultTopics: [.ai])
    ]
}

private struct RedditListingResponse: Decodable {
    let data: RedditListingData
}

private struct RedditListingData: Decodable {
    let children: [RedditChild]
}

private struct RedditChild: Decodable {
    let data: RedditPost
}

private struct RedditPost: Decodable {
    let title: String
    let url: String?
    let selftext: String?
    let score: Int
    let numComments: Int
    let createdUTC: TimeInterval
    let isSelf: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case selftext
        case score
        case numComments = "num_comments"
        case createdUTC = "created_utc"
        case isSelf = "is_self"
    }
}
