import Foundation

enum Topic: String, CaseIterable, Identifiable, Hashable {
    case web
    case ios
    case android
    case backend
    case ai
    case devops
    case security
    case product

    var id: String { rawValue }

    var title: String {
        switch self {
        case .web: "Web"
        case .ios: "iOS"
        case .android: "Android"
        case .backend: "Backend"
        case .ai: "AI"
        case .devops: "DevOps"
        case .security: "Security"
        case .product: "Product"
        }
    }

    var symbolName: String {
        switch self {
        case .web: "globe"
        case .ios: "iphone"
        case .android: "ladybug"
        case .backend: "server.rack"
        case .ai: "sparkles"
        case .devops: "shippingbox"
        case .security: "lock.shield"
        case .product: "square.stack.3d.up"
        }
    }
}

struct EngagementMetrics: Hashable {
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

    var title: String {
        switch self {
        case .recentlySaved: "Recently saved"
        case .trending: "Trending"
        }
    }
}

enum SourceCategory: String, CaseIterable, Identifiable, Hashable {
    case article
    case hackerNews
    case reddit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .article: "Articles"
        case .hackerNews: "Hacker News"
        case .reddit: "Reddit"
        }
    }

    var symbolName: String {
        switch self {
        case .article: "newspaper"
        case .hackerNews: "flame"
        case .reddit: "bubble.left.and.bubble.right"
        }
    }
}

struct ContentItem: Identifiable, Hashable {
    enum Kind: String {
        case article
        case discussion

        var title: String {
            switch self {
            case .article: "Article"
            case .discussion: "Discussion"
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
        engagement: EngagementMetrics? = nil
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
    }
}
