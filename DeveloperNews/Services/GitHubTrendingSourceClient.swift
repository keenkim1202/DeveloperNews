import Foundation

private actor GitHubRepositorySearchCache {
    struct Entry {
        let repositories: [GitHubRepo]
        let expiresAt: Date
    }

    private var storage: [String: Entry] = [:]
    private let ttl: TimeInterval = 10 * 60

    func repositories(for key: String) -> [GitHubRepo]? {
        guard let entry = storage[key], entry.expiresAt > Date() else {
            storage[key] = nil
            return nil
        }
        return entry.repositories
    }

    func setRepositories(
        _ repositories: [GitHubRepo],
        for key: String,
    ) {
        storage[key] = Entry(
            repositories: repositories,
            expiresAt: Date().addingTimeInterval(ttl))
    }
}

struct GitHubTrendingSourceClient: ContentSourceClient {
    private static let cache = GitHubRepositorySearchCache()

    let session: URLSession
    let maxResults: Int

    init(
        session: URLSession = .shared,
        maxResults: Int = 15,
    ) {
        self.session = session
        self.maxResults = maxResults
    }

    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        let targetCount = fetchLimit(for: selectedTopics)
        let baseRepositories = try await fetchRepositories(query: broadSearchQuery(), limit: targetCount)
        var repositories = baseRepositories

        if selectedTopics.count == 1, let topic = selectedTopics.first {
            var matchingCount = mappedItems(from: repositories).filter { $0.topics.contains(topic) }.count
            let supplementQueries = topicSpecificSupplementQueries(for: topic)

            for query in supplementQueries where matchingCount < targetCount {
                let supplementalRepositories = try await fetchRepositories(query: query, limit: max(10, targetCount / 2))
                repositories.append(contentsOf: supplementalRepositories)
                matchingCount = mappedItems(from: repositories).filter { $0.topics.contains(topic) }.count
            }
        }

        return mappedItems(from: repositories)
    }

    private func mappedItems(from repositories: [GitHubRepo]) -> [ContentItem] {
        var seenURLs = Set<String>()
        return repositories.compactMap { repo in
            guard let link = URL(string: repo.htmlURL) else {
                return nil
            }
            guard seenURLs.insert(repo.htmlURL).inserted else {
                return nil
            }

            let score = min(95, max(60, 60 + repo.stargazersCount / 200))

            return ContentItem(
                id: UUID(),
                kind: .article,
                title: repo.fullName,
                summary: repo.description ?? "Trending GitHub repository.",
                sourceName: "GitHub Trending",
                sourceCategory: .github,
                authorName: repo.owner.login,
                url: link,
                publishedAt: repo.pushedAt,
                topics: inferredTopics(
                    language: repo.language,
                    topics: repo.topics),
                trendScore: score,
                thumbnailURL: nil,
                engagement: EngagementMetrics(
                    reactionCount: repo.stargazersCount,
                    commentCount: repo.forksCount))
        }
    }

    private func dateString(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Date().addingTimeInterval(-Double(daysAgo) * 24 * 60 * 60)
        return formatter.string(from: date)
    }

    private func fetchLimit(for selectedTopics: Set<Topic>) -> Int {
        selectedTopics.count == 1 ? max(30, maxResults) : maxResults
    }

    private func fetchRepositories(
        query: String,
        limit: Int,
    ) async throws -> [GitHubRepo] {
        let cacheKey = "\(query)|\(limit)"
        if let cached = await Self.cache.repositories(for: cacheKey) {
            return cached
        }

        var components = URLComponents(string: "https://api.github.com/search/repositories")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue(AppIdentity.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(GitHubSearchResponse.self, from: data)
        await Self.cache.setRepositories(response.items, for: cacheKey)
        return response.items
    }

    private func broadSearchQuery() -> String {
        "stars:>100 pushed:>\(dateString(daysAgo: 7))"
    }

    private func topicSpecificSupplementQueries(for topic: Topic) -> [String] {
        let recency = "pushed:>\(dateString(daysAgo: 7))"

        switch topic {
        case .ios:
            return [
                "language:Swift stars:>20 \(recency)",
                "topic:ios stars:>20 \(recency)",
                "swiftui stars:>20 \(recency)",
            ]
        case .android:
            return [
                "language:Kotlin stars:>20 \(recency)",
                "topic:android stars:>20 \(recency)",
                "\"jetpack compose\" stars:>20 \(recency)",
            ]
        case .web:
            return [
                "language:TypeScript stars:>20 \(recency)",
                "language:JavaScript stars:>20 \(recency)",
                "topic:frontend stars:>20 \(recency)",
            ]
        case .backend:
            return [
                "language:Go stars:>20 \(recency)",
                "language:Rust stars:>20 \(recency)",
                "topic:backend stars:>20 \(recency)",
            ]
        case .ai:
            return [
                "topic:ai stars:>20 \(recency)",
                "topic:llm stars:>20 \(recency)",
                "topic:machine-learning stars:>20 \(recency)",
            ]
        case .security:
            return [
                "topic:security stars:>20 \(recency)",
                "topic:auth stars:>20 \(recency)",
                "topic:cryptography stars:>20 \(recency)",
            ]
        case .product:
            return [
                "topic:productivity stars:>20 \(recency)",
                "topic:\"developer-tools\" stars:>20 \(recency)",
                "topic:cli stars:>20 \(recency)",
            ]
        }
    }

    private func inferredTopics(language: String?, topics: [String]?) -> [Topic] {
        let languagePart = language?.lowercased() ?? ""
        let topicsPart = (topics ?? []).map { $0.lowercased() }.joined(separator: " ")
        let normalized = languagePart + " " + topicsPart

        let rules: [(Topic, [String])] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["kotlin", "android", "jetpack"]),
            (.web, ["javascript", "typescript", "react", "vue", "svelte", "nextjs", "html", "css", "tailwind", "web"]),
            (.backend, ["go", "golang", "rust", "python", "java", "ruby", "postgres", "mysql", "redis", "kafka", "microservice", "api", "docker", "kubernetes", "k8s", "terraform", "ansible", "ci", "cd", "devops", "deploy", "infrastructure"]),
            (.ai, ["ai", "llm", "ml", "machine-learning", "machinelearning", "transformer", "pytorch", "tensorflow", "embedding", "rag", "openai"]),
            (.security, ["security", "crypto", "auth", "oauth", "vulnerability", "encryption"]),
            (.product, ["design", "ux", "ui", "productivity", "cli", "tool"])
        ]

        var matched: Set<Topic> = []
        for (topic, keywords) in rules {
            if keywords.contains(where: normalized.contains) {
                matched.insert(topic)
            }
        }

        if matched.isEmpty {
            return [.backend]
        }
        return Array(matched)
    }
}

private struct GitHubSearchResponse: Decodable {
    let items: [GitHubRepo]
}

private struct GitHubRepo: Decodable {
    let fullName: String
    let description: String?
    let htmlURL: String
    let stargazersCount: Int
    let forksCount: Int
    let language: String?
    let topics: [String]?
    let pushedAt: Date
    let owner: GitHubOwner

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case description
        case htmlURL = "html_url"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case language
        case topics
        case pushedAt = "pushed_at"
        case owner
    }
}

private struct GitHubOwner: Decodable {
    let login: String
}
