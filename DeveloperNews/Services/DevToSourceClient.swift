import Foundation

struct DevToSourceClient: ContentSourceClient {
    let session: URLSession
    let maxItems: Int

    init(
        session: URLSession = .shared,
        maxItems: Int = 30,
    ) {
        self.session = session
        self.maxItems = maxItems
    }

    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        var components = URLComponents(string: "https://dev.to/api/articles")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "top", value: "7"),
            URLQueryItem(name: "per_page", value: "\(fetchLimit(for: selectedTopics))")
        ]
        if selectedTopics.count == 1, let topic = selectedTopics.first, let tag = Self.devToTag(for: topic) {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(AppIdentity.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let articles = try decoder.decode([DevToArticle].self, from: data)

        return articles.compactMap { article in
            guard let link = URL(string: article.url) else { return nil }
            let thumbnail = article.coverImage.flatMap { URL(string: $0) }
            return ContentItem(
                id: UUID(),
                kind: .article,
                title: article.title,
                summary: article.description,
                sourceName: "DEV.to",
                sourceCategory: .article,
                authorName: article.user.name,
                url: link,
                publishedAt: article.publishedAt,
                topics: inferredTopics(tags: article.tagList),
                trendScore: trendScore(reactions: article.publicReactionsCount, comments: article.commentsCount),
                thumbnailURL: thumbnail,
                engagement: EngagementMetrics(reactionCount: article.publicReactionsCount, commentCount: article.commentsCount))
        }
    }

    private func fetchLimit(for selectedTopics: Set<Topic>) -> Int {
        selectedTopics.count == 1 ? max(30, maxItems) : maxItems
    }

    private static func devToTag(for topic: Topic) -> String? {
        switch topic {
        case .ios: "swift"
        case .android: "android"
        case .web: "webdev"
        case .backend: "backend"
        case .ai: "ai"
        case .security: "security"
        case .product: "productivity"
        }
    }

    private func trendScore(
        reactions: Int,
        comments: Int,
    ) -> Int {
        let raw = 60 + reactions / 5 + comments / 2
        return min(95, max(60, raw))
    }

    private func inferredTopics(tags: [String]) -> [Topic] {
        let normalized = Set(tags.map { $0.lowercased() })
        var topics: Set<Topic> = []

        let rules: [(Topic, Set<String>)] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["android", "kotlin", "jetpack"]),
            (.web, ["javascript", "typescript", "react", "vue", "svelte", "nextjs", "html", "css", "tailwind", "web", "frontend", "webdev"]),
            (.backend, ["python", "rust", "go", "golang", "java", "ruby", "php", "node", "nodejs", "postgres", "database", "api", "backend", "microservices"]),
            (.ai, ["ai", "llm", "machinelearning", "machine-learning", "ml", "openai", "claude", "gemini", "rag", "embeddings"]),
            (.security, ["security", "cybersecurity", "auth", "oauth", "vulnerability", "encryption"]),
            (.product, ["productivity", "career", "design", "ux", "startup", "entrepreneurship", "indiehackers"])
        ]

        for (topic, keywords) in rules where !normalized.isDisjoint(with: keywords) {
            topics.insert(topic)
        }

        return topics.isEmpty ? [.product] : Array(topics)
    }
}

private struct DevToArticle: Decodable {
    let id: Int
    let title: String
    let description: String
    let url: String
    let coverImage: String?
    let publishedAt: Date
    let tagList: [String]
    let publicReactionsCount: Int
    let commentsCount: Int
    let user: DevToUser

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case url
        case coverImage = "cover_image"
        case publishedAt = "published_at"
        case tagList = "tag_list"
        case publicReactionsCount = "public_reactions_count"
        case commentsCount = "comments_count"
        case user
    }
}

private struct DevToUser: Decodable {
    let name: String
}
