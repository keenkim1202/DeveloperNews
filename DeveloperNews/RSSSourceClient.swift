import Foundation

struct RSSFeedDefinition {
    let sourceName: String
    let feedURL: URL
    let defaultTopics: [Topic]
}

struct RSSSourceClient: ContentSourceClient {
    let feeds: [RSSFeedDefinition]
    let session: URLSession

    init(
        feeds: [RSSFeedDefinition] = Self.defaultFeeds,
        session: URLSession = .shared
    ) {
        self.feeds = feeds
        self.session = session
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

    private func fetchItems(for feed: RSSFeedDefinition) async throws -> [ContentItem] {
        let (data, _) = try await session.data(from: feed.feedURL)
        let parsedItems = try RSSFeedParser().parse(data: data)

        return parsedItems.prefix(8).map { item in
            ContentItem(
                id: UUID(),
                kind: .article,
                title: item.title,
                summary: item.summary,
                sourceName: feed.sourceName,
                authorName: item.author,
                url: item.link,
                publishedAt: item.publishedAt,
                topics: inferredTopics(for: item.title + " " + item.summary, fallback: feed.defaultTopics),
                trendScore: trendScore(for: item.publishedAt)
            )
        }
    }

    private func inferredTopics(for text: String, fallback: [Topic]) -> [Topic] {
        let normalized = text.lowercased()
        var topics = Set(fallback)

        let rules: [(Topic, [String])] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["android", "kotlin", "jetpack", "gradle"]),
            (.web, ["web", "javascript", "typescript", "react", "css"]),
            (.backend, ["backend", "server", "database", "api", "postgres"]),
            (.ai, ["ai", "llm", "model", "rag", "embedding", "openai"]),
            (.devops, ["docker", "kubernetes", "deploy", "ci", "cd", "infra"]),
            (.security, ["security", "auth", "oauth", "token", "vulnerability"]),
            (.product, ["product", "design", "ux", "roadmap", "team"])
        ]

        for (topic, keywords) in rules {
            if keywords.contains(where: normalized.contains) {
                topics.insert(topic)
            }
        }

        return Array(topics)
    }

    private func trendScore(for publishedAt: Date) -> Int {
        let hoursAgo = max(1, Int(Date().timeIntervalSince(publishedAt) / 3600))
        return max(55, 100 - hoursAgo)
    }
}

extension RSSSourceClient {
    static let defaultFeeds: [RSSFeedDefinition] = [
        RSSFeedDefinition(
            sourceName: "Swift with Majid",
            feedURL: URL(string: "https://swiftwithmajid.com/feed.xml")!,
            defaultTopics: [.ios, .product]
        ),
        RSSFeedDefinition(
            sourceName: "InfoQ",
            feedURL: URL(string: "https://feed.infoq.com")!,
            defaultTopics: [.backend, .ai, .product]
        ),
        RSSFeedDefinition(
            sourceName: "GitHub Blog",
            feedURL: URL(string: "https://github.blog/feed/")!,
            defaultTopics: [.devops, .product]
        ),
        RSSFeedDefinition(
            sourceName: "Mozilla Hacks",
            feedURL: URL(string: "https://hacks.mozilla.org/feed/")!,
            defaultTopics: [.web, .security]
        ),
        RSSFeedDefinition(
            sourceName: "Cloudflare Blog",
            feedURL: URL(string: "https://blog.cloudflare.com/rss/")!,
            defaultTopics: [.backend, .devops, .security]
        )
    ]
}

private struct ParsedRSSItem {
    let title: String
    let summary: String
    let link: URL
    let author: String?
    let publishedAt: Date
}

private final class RSSFeedParser: NSObject, XMLParserDelegate {
    private enum Element: String {
        case item
        case title
        case description
        case link
        case author
        case creator = "dc:creator"
        case pubDate
    }

    private struct PartialItem {
        var title = ""
        var description = ""
        var link = ""
        var author = ""
        var publishedAt: Date?
    }

    private var parsedItems: [ParsedRSSItem] = []
    private var currentItem: PartialItem?
    private var currentElement: Element?
    private var currentText = ""

    func parse(data: Data) throws -> [ParsedRSSItem] {
        parsedItems = []
        currentItem = nil
        currentElement = nil
        currentText = ""

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }

        return parsedItems
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String : String] = [:]) {
        currentText = ""

        if elementName == Element.item.rawValue {
            currentItem = PartialItem()
        }

        currentElement = Element(rawValue: elementName)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var item = currentItem else {
            currentElement = nil
            currentText = ""
            return
        }

        if elementName == Element.item.rawValue {
            if
                let publishedAt = item.publishedAt,
                let link = URL(string: item.link),
                !item.title.isEmpty
            {
                parsedItems.append(
                    ParsedRSSItem(
                        title: item.title,
                        summary: sanitizedSummary(from: item.description),
                        link: link,
                        author: item.author.isEmpty ? nil : item.author,
                        publishedAt: publishedAt
                    )
                )
            }

            currentItem = nil
            currentElement = nil
            currentText = ""
            return
        }

        guard let currentElement else {
            currentText = ""
            return
        }

        switch currentElement {
        case .title:
            item.title = trimmedText
        case .description:
            item.description = trimmedText
        case .link:
            item.link = trimmedText
        case .author, .creator:
            item.author = trimmedText
        case .pubDate:
            item.publishedAt = parsedDate(from: trimmedText)
        case .item:
            break
        }

        currentItem = item
        self.currentElement = nil
        currentText = ""
    }

    private func parsedDate(from string: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "E, dd MMM yyyy HH:mm:ss Z"
                return formatter
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    private func sanitizedSummary(from rawHTML: String) -> String {
        let withoutTags = rawHTML.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        let collapsedWhitespace = withoutTags.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return collapsedWhitespace
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
