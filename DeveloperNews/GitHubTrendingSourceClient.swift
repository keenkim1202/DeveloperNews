import Foundation

struct GitHubTrendingSourceClient: ContentSourceClient {
    let session: URLSession
    let maxResults: Int

    init(session: URLSession = .shared, maxResults: Int = 15) {
        self.session = session
        self.maxResults = maxResults
    }

    func fetchItems() async throws -> [ContentItem] {
        var components = URLComponents(string: "https://api.github.com/search/repositories")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "stars:>100 pushed:>\(dateString(daysAgo: 7))"),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "\(maxResults)")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("DeveloperNews/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(GitHubSearchResponse.self, from: data)

        return response.items.compactMap { repo in
            guard let link = URL(string: repo.htmlURL) else {
                return nil
            }

            let score = min(95, max(60, 60 + repo.stargazersCount / 200))

            return ContentItem(
                id: UUID(),
                kind: .article,
                title: repo.fullName,
                summary: repo.description ?? "Trending GitHub repository.",
                sourceName: "GitHub Trending",
                sourceCategory: .article,
                authorName: repo.owner.login,
                url: link,
                publishedAt: repo.pushedAt,
                topics: inferredTopics(language: repo.language, topics: repo.topics),
                trendScore: score,
                thumbnailURL: nil,
                engagement: EngagementMetrics(reactionCount: repo.stargazersCount, commentCount: repo.forksCount)
            )
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

    private func inferredTopics(language: String?, topics: [String]?) -> [Topic] {
        let languagePart = language?.lowercased() ?? ""
        let topicsPart = (topics ?? []).map { $0.lowercased() }.joined(separator: " ")
        let normalized = languagePart + " " + topicsPart

        let rules: [(Topic, [String])] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["kotlin", "android", "jetpack"]),
            (.web, ["javascript", "typescript", "react", "vue", "svelte", "nextjs", "html", "css", "tailwind", "web"]),
            (.backend, ["go", "golang", "rust", "python", "java", "ruby", "postgres", "mysql", "redis", "kafka", "microservice", "api"]),
            (.ai, ["ai", "llm", "ml", "machine-learning", "machinelearning", "transformer", "pytorch", "tensorflow", "embedding", "rag", "openai"]),
            (.devops, ["docker", "kubernetes", "k8s", "terraform", "ansible", "ci", "cd", "devops", "deploy", "infrastructure"]),
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
