import Foundation

enum SampleData {
    static let items: [ContentItem] = [
        ContentItem(
            id: UUID(),
            kind: .article,
            title: "SwiftUI navigation patterns for larger apps",
            summary: "A practical breakdown of routing, view ownership, and feature boundaries in production SwiftUI apps.",
            sourceName: "Swift with Majid",
            sourceCategory: .article,
            authorName: "Majid Jabrayilov",
            url: URL(string: "https://swiftwithmajid.com")!,
            publishedAt: .now.addingTimeInterval(-60 * 40),
            topics: [.ios, .product],
            trendScore: 92
        ),
        ContentItem(
            id: UUID(),
            kind: .discussion,
            title: "Show HN: A tiny deployment tool for side projects",
            summary: "A Hacker News thread discussing lightweight deployment workflows and tradeoffs against larger platforms.",
            sourceName: "Hacker News",
            sourceCategory: .hackerNews,
            authorName: nil,
            url: URL(string: "https://news.ycombinator.com")!,
            publishedAt: .now.addingTimeInterval(-60 * 90),
            topics: [.backend, .devops],
            trendScore: 88
        ),
        ContentItem(
            id: UUID(),
            kind: .article,
            title: "What changed in Android build performance this month",
            summary: "A monthly summary covering Gradle performance wins, emulator improvements, and profiling tips.",
            sourceName: "Android Developers",
            sourceCategory: .article,
            authorName: nil,
            url: URL(string: "https://developer.android.com")!,
            publishedAt: .now.addingTimeInterval(-60 * 180),
            topics: [.android, .product],
            trendScore: 83
        ),
        ContentItem(
            id: UUID(),
            kind: .article,
            title: "How teams are shipping RAG apps with smaller models",
            summary: "An overview of current AI product patterns focused on retrieval, evals, latency, and cost control.",
            sourceName: "InfoQ",
            sourceCategory: .article,
            authorName: nil,
            url: URL(string: "https://www.infoq.com")!,
            publishedAt: .now.addingTimeInterval(-60 * 240),
            topics: [.ai, .backend, .product],
            trendScore: 95
        ),
        ContentItem(
            id: UUID(),
            kind: .discussion,
            title: "Reddit: What is your backend stack in 2026?",
            summary: "A developer discussion comparing Go, TypeScript, Rust, Postgres, and managed infrastructure choices.",
            sourceName: "Reddit",
            sourceCategory: .reddit,
            authorName: "r/backend",
            url: URL(string: "https://www.reddit.com")!,
            publishedAt: .now.addingTimeInterval(-60 * 300),
            topics: [.backend, .web],
            trendScore: 79
        ),
    ]
}
