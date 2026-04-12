import Foundation

enum Topic: String, CaseIterable, Identifiable, Hashable, Codable {
    case web
    case ios
    case android
    case backend
    case ai
    case security
    case product

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .web: "topic.web"
        case .ios: "topic.ios"
        case .android: "topic.android"
        case .backend: "topic.backend"
        case .ai: "topic.ai"
        case .security: "topic.security"
        case .product: "topic.product"
        }
    }

    var symbolName: String {
        switch self {
        case .web: "globe"
        case .ios: "iphone"
        case .android: "ladybug"
        case .backend: "server.rack"
        case .ai: "sparkles"
        case .security: "lock.shield"
        case .product: "square.stack.3d.up"
        }
    }
}

struct EngagementMetrics: Hashable, Codable {
    let reactionCount: Int
    let commentCount: Int
}

enum AppTab: String, Hashable {
    case home
    case saved
    case settings
}

enum SavedSortOrder: String, CaseIterable, Identifiable, Hashable {
    case recentlySaved
    case trending

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .recentlySaved: "savedSort.recentlySaved"
        case .trending: "savedSort.trending"
        }
    }
}

enum SourceCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case article
    case hackerNews
    case reddit
    case github

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .article: "source.articles"
        case .hackerNews: "source.hackerNews"
        case .reddit: "source.reddit"
        case .github: "source.github"
        }
    }

    var symbolName: String {
        switch self {
        case .article: "newspaper"
        case .hackerNews: "flame"
        case .reddit: "bubble.left.and.bubble.right"
        case .github: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ContentItem: Identifiable, Hashable, Codable {
    enum Kind: String, Codable {
        case article
        case discussion

        var title: LocalizedStringResource {
            switch self {
            case .article: "kind.article"
            case .discussion: "kind.discussion"
            }
        }

        var symbolName: String {
            switch self {
            case .article: "newspaper"
            case .discussion: "bubble.left.and.bubble.right"
            }
        }
    }

    let id: UUID
    let kind: Kind
    let title: String
    let summary: String
    let sourceName: String
    let sourceCategory: SourceCategory
    let authorName: String?
    let url: URL
    let publishedAt: Date
    let topics: [Topic]
    let trendScore: Int
    let thumbnailURL: URL?
    let engagement: EngagementMetrics?
    let isUserCreated: Bool
    let updatedAt: Date?

    init(
        id: UUID,
        kind: Kind,
        title: String,
        summary: String,
        sourceName: String,
        sourceCategory: SourceCategory,
        authorName: String?,
        url: URL,
        publishedAt: Date,
        topics: [Topic],
        trendScore: Int,
        thumbnailURL: URL? = nil,
        engagement: EngagementMetrics? = nil,
        isUserCreated: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.sourceName = sourceName
        self.sourceCategory = sourceCategory
        self.authorName = authorName
        self.url = url
        self.publishedAt = publishedAt
        self.topics = topics
        self.trendScore = trendScore
        self.thumbnailURL = thumbnailURL
        self.engagement = engagement
        self.isUserCreated = isUserCreated
        self.updatedAt = updatedAt
    }

    var hasExternalLink: Bool {
        url.scheme == "https" || url.scheme == "http"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        sourceName = try container.decode(String.self, forKey: .sourceName)
        sourceCategory = try container.decode(SourceCategory.self, forKey: .sourceCategory)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        url = try container.decode(URL.self, forKey: .url)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        topics = try container.decode([Topic].self, forKey: .topics)
        trendScore = try container.decode(Int.self, forKey: .trendScore)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        engagement = try container.decodeIfPresent(EngagementMetrics.self, forKey: .engagement)
        isUserCreated = try container.decodeIfPresent(Bool.self, forKey: .isUserCreated) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}
