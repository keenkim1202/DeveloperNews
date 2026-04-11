import Foundation

struct HackerNewsSourceClient: ContentSourceClient {
    let session: URLSession
    let maxStories: Int

    init(session: URLSession = .shared, maxStories: Int = 12) {
        self.session = session
        self.maxStories = maxStories
    }

    func fetchItems() async throws -> [ContentItem] {
        let topStoryIDs = try await fetchTopStoryIDs()

        return await withTaskGroup(of: ContentItem?.self) { group in
            for id in topStoryIDs.prefix(maxStories) {
                group.addTask {
                    try? await fetchStory(id: id)
                }
            }

            var combined: [ContentItem] = []
            for await item in group {
                if let item {
                    combined.append(item)
                }
            }
            return combined
        }
    }

    private func fetchTopStoryIDs() async throws -> [Int] {
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
        var request = URLRequest(url: url)
        request.setValue(AppContact.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([Int].self, from: data)
    }

    private func fetchStory(id: Int) async throws -> ContentItem? {
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json")!
        var request = URLRequest(url: url)
        request.setValue(AppContact.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        let story = try JSONDecoder().decode(HNStory.self, from: data)

        guard
            story.type == "story",
            let title = story.title,
            let urlString = story.url,
            let link = URL(string: urlString)
        else {
            return nil
        }

        let publishedAt = Date(timeIntervalSince1970: TimeInterval(story.time))
        let score = max(60, min(98, 55 + story.score / 2))
        let topics = inferredTopics(for: title + " " + urlString)

        return ContentItem(
            id: UUID(),
            kind: .discussion,
            title: title,
            summary: "Trending discussion from Hacker News.",
            sourceName: "Hacker News",
            sourceCategory: .hackerNews,
            authorName: story.by,
            url: link,
            publishedAt: publishedAt,
            topics: topics,
            trendScore: score,
            engagement: EngagementMetrics(reactionCount: story.score, commentCount: story.descendants ?? 0)
        )
    }

    private func inferredTopics(for text: String) -> [Topic] {
        let normalized = text.lowercased()
        var topics: Set<Topic> = [.web, .backend]

        let rules: [(Topic, [String])] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["android", "kotlin", "jetpack", "gradle"]),
            (.web, ["web", "javascript", "typescript", "react", "browser"]),
            (.backend, ["server", "database", "backend", "api", "postgres", "docker", "kubernetes", "deploy", "infrastructure", "ci"]),
            (.ai, ["ai", "llm", "model", "agent", "rag", "openai"]),
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
}

private struct HNStory: Decodable {
    let type: String?
    let title: String?
    let url: String?
    let by: String?
    let score: Int
    let time: Int
    let descendants: Int?
}
