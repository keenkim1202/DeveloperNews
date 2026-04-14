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

    private static let maxConcurrentFetches = 6

    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        await withTaskGroup(of: [ContentItem].self) { group in
            var iterator = feeds.makeIterator()

            for _ in 0..<Self.maxConcurrentFetches {
                guard let feed = iterator.next() else { break }
                group.addTask {
                    (try? await fetchItems(for: feed)) ?? []
                }
            }

            var combined: [ContentItem] = []
            while let items = await group.next() {
                combined.append(contentsOf: items)
                if let nextFeed = iterator.next() {
                    group.addTask {
                        (try? await fetchItems(for: nextFeed)) ?? []
                    }
                }
            }
            return combined
        }
    }

    private func fetchItems(for feed: RedditFeedDefinition) async throws -> [ContentItem] {
        let url = URL(string: "https://www.reddit.com/r/\(feed.subreddit).json")!
        var request = URLRequest(url: url)
        request.setValue(AppContact.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(RedditListingResponse.self, from: data)

        let eligiblePosts = response.data.children.lazy
            .map(\.data)
            .filter { post in
                !post.over18
                    && !post.spoiler
                    && !post.stickied
                    && !post.locked
                    && !post.quarantine
            }

        return eligiblePosts.prefix(maxItemsPerFeed).compactMap { post in
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
                sourceCategory: .reddit,
                authorName: "r/\(feed.subreddit)",
                url: link,
                publishedAt: publishedAt,
                topics: topics,
                trendScore: trendScore(score: post.score, commentCount: post.numComments, publishedAt: publishedAt),
                thumbnailURL: thumbnailURL(from: post),
                engagement: EngagementMetrics(reactionCount: post.score, commentCount: post.numComments)
            )
        }
    }

    private func thumbnailURL(from post: RedditPost) -> URL? {
        let placeholders: Set<String> = ["self", "default", "nsfw", "spoiler", "image", ""]
        guard
            let raw = post.thumbnail,
            !placeholders.contains(raw),
            raw.hasPrefix("https://") || raw.hasPrefix("http://")
        else {
            return nil
        }

        let decoded = raw
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        return URL(string: decoded)
    }

    private func inferredTopics(for text: String, fallback: [Topic]) -> [Topic] {
        let normalized = text.lowercased()
        var topics = Set(fallback)

        let rules: [(Topic, [String])] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["android", "kotlin", "jetpack", "gradle"]),
            (.web, ["web", "javascript", "typescript", "react", "browser"]),
            (.backend, ["server", "database", "backend", "api", "postgres", "docker", "kubernetes", "deploy", "infrastructure", "ci"]),
            (.ai, ["ai", "llm", "model", "agent", "rag", "openai", "machine learning"]),
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
        RedditFeedDefinition(subreddit: "ios", defaultTopics: [.ios]),
        RedditFeedDefinition(subreddit: "swift", defaultTopics: [.ios]),
        RedditFeedDefinition(subreddit: "swiftui", defaultTopics: [.ios]),
        RedditFeedDefinition(subreddit: "apple", defaultTopics: [.ios, .product]),
        RedditFeedDefinition(subreddit: "Xcode", defaultTopics: [.ios]),
        RedditFeedDefinition(subreddit: "VisionPro", defaultTopics: [.ios]),
        RedditFeedDefinition(subreddit: "WWDC", defaultTopics: [.ios]),
        RedditFeedDefinition(subreddit: "androiddev", defaultTopics: [.android]),
        RedditFeedDefinition(subreddit: "android", defaultTopics: [.android]),
        RedditFeedDefinition(subreddit: "Kotlin", defaultTopics: [.android]),
        RedditFeedDefinition(subreddit: "jetpackcompose", defaultTopics: [.android]),
        RedditFeedDefinition(subreddit: "FlutterDev", defaultTopics: [.android, .ios]),
        RedditFeedDefinition(subreddit: "AndroidStudio", defaultTopics: [.android]),
        RedditFeedDefinition(subreddit: "Kotlin_Multiplatform", defaultTopics: [.android, .ios]),
        RedditFeedDefinition(subreddit: "javascript", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "typescript", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "reactjs", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "nextjs", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "vuejs", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "sveltejs", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "node", defaultTopics: [.web, .backend]),
        RedditFeedDefinition(subreddit: "Bun", defaultTopics: [.web, .backend]),
        RedditFeedDefinition(subreddit: "htmx", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "tailwindcss", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "Frontend", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "css", defaultTopics: [.web]),
        RedditFeedDefinition(subreddit: "rust", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "golang", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "Python", defaultTopics: [.backend, .ai]),
        RedditFeedDefinition(subreddit: "elixir", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "Zig", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "haskell", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "PostgreSQL", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "dataengineering", defaultTopics: [.backend, .ai]),
        RedditFeedDefinition(subreddit: "kubernetes", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "docker", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "Terraform", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "aws", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "devops", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "sysadmin", defaultTopics: [.backend]),
        RedditFeedDefinition(subreddit: "MachineLearning", defaultTopics: [.ai]),
        RedditFeedDefinition(subreddit: "LocalLLaMA", defaultTopics: [.ai]),
        RedditFeedDefinition(subreddit: "ChatGPT", defaultTopics: [.ai]),
        RedditFeedDefinition(subreddit: "ClaudeAI", defaultTopics: [.ai]),
        RedditFeedDefinition(subreddit: "OpenAI", defaultTopics: [.ai]),
        RedditFeedDefinition(subreddit: "GoogleGeminiAI", defaultTopics: [.ai]),
        RedditFeedDefinition(subreddit: "StableDiffusion", defaultTopics: [.ai]),
        RedditFeedDefinition(subreddit: "LangChain", defaultTopics: [.ai, .backend]),
        RedditFeedDefinition(subreddit: "cursor", defaultTopics: [.ai, .product]),
        RedditFeedDefinition(subreddit: "GithubCopilot", defaultTopics: [.ai, .product]),
        RedditFeedDefinition(subreddit: "netsec", defaultTopics: [.security]),
        RedditFeedDefinition(subreddit: "cybersecurity", defaultTopics: [.security]),
        RedditFeedDefinition(subreddit: "AskNetsec", defaultTopics: [.security]),
        RedditFeedDefinition(subreddit: "cryptography", defaultTopics: [.security]),
        RedditFeedDefinition(subreddit: "ReverseEngineering", defaultTopics: [.security]),
        RedditFeedDefinition(subreddit: "ExperiencedDevs", defaultTopics: [.product]),
        RedditFeedDefinition(subreddit: "SideProject", defaultTopics: [.product]),
        RedditFeedDefinition(subreddit: "startups", defaultTopics: [.product]),
        RedditFeedDefinition(subreddit: "Entrepreneur", defaultTopics: [.product])
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
    let over18: Bool
    let spoiler: Bool
    let stickied: Bool
    let locked: Bool
    let quarantine: Bool
    let thumbnail: String?

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case selftext
        case score
        case numComments = "num_comments"
        case createdUTC = "created_utc"
        case isSelf = "is_self"
        case over18 = "over_18"
        case spoiler
        case stickied
        case locked
        case quarantine
        case thumbnail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        selftext = try container.decodeIfPresent(String.self, forKey: .selftext)
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        numComments = try container.decodeIfPresent(Int.self, forKey: .numComments) ?? 0
        createdUTC = try container.decodeIfPresent(TimeInterval.self, forKey: .createdUTC) ?? 0
        isSelf = try container.decodeIfPresent(Bool.self, forKey: .isSelf) ?? false
        over18 = try container.decodeIfPresent(Bool.self, forKey: .over18) ?? false
        spoiler = try container.decodeIfPresent(Bool.self, forKey: .spoiler) ?? false
        stickied = try container.decodeIfPresent(Bool.self, forKey: .stickied) ?? false
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        quarantine = try container.decodeIfPresent(Bool.self, forKey: .quarantine) ?? false
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
    }
}
