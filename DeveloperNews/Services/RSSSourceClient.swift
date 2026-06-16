import Foundation

struct RSSFeedDefinition: Sendable {
    let sourceName: String
    let feedURL: URL
    let defaultTopics: [Topic]
}

struct RSSSourceClient: ContentSourceClient {
    let feeds: [RSSFeedDefinition]
    let session: URLSession

    init(
        feeds: [RSSFeedDefinition] = Self.defaultFeeds,
        session: URLSession = .shared,
    ) {
        self.feeds = feeds
        self.session = session
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

    private func fetchItems(for feed: RSSFeedDefinition) async throws -> [ContentItem] {
        var request = URLRequest(url: feed.feedURL)
        request.setValue(AppIdentity.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        let parsedItems = try RSSFeedParser().parse(data: data)

        return parsedItems.prefix(8).map { item in
            ContentItem(
                id: UUID(),
                kind: .article,
                title: item.title,
                summary: item.summary,
                sourceName: feed.sourceName,
                sourceCategory: .article,
                authorName: item.author,
                url: item.link,
                publishedAt: item.publishedAt,
                topics: inferredTopics(for: item.title + " " + item.summary, fallback: feed.defaultTopics),
                trendScore: trendScore(for: item.publishedAt),
                thumbnailURL: item.imageURL)
        }
    }

    private func inferredTopics(
        for text: String,
        fallback: [Topic],
    ) -> [Topic] {
        let normalized = text.lowercased()
        var topics = Set(fallback)

        let rules: [(Topic, [String])] = [
            (.ios, ["swift", "swiftui", "ios", "xcode"]),
            (.android, ["android", "kotlin", "jetpack", "gradle"]),
            (.web, ["web", "javascript", "typescript", "react", "css"]),
            (.backend, ["backend", "server", "database", "api", "postgres", "docker", "kubernetes", "deploy", "ci", "cd", "infra"]),
            (.ai, ["ai", "llm", "model", "rag", "embedding", "openai"]),
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
            feedURL: URL(static: "https://swiftwithmajid.com/feed.xml"),
            defaultTopics: [.ios, .product]),
        RSSFeedDefinition(
            sourceName: "InfoQ",
            feedURL: URL(static: "https://feed.infoq.com"),
            defaultTopics: [.backend, .ai, .product]),
        RSSFeedDefinition(
            sourceName: "GitHub Blog",
            feedURL: URL(static: "https://github.blog/feed/"),
            defaultTopics: [.backend, .product]),
        RSSFeedDefinition(
            sourceName: "Mozilla Hacks",
            feedURL: URL(static: "https://hacks.mozilla.org/feed/"),
            defaultTopics: [.web, .security]),
        RSSFeedDefinition(
            sourceName: "Cloudflare Blog",
            feedURL: URL(static: "https://blog.cloudflare.com/rss/"),
            defaultTopics: [.backend, .security]),
        RSSFeedDefinition(
            sourceName: "Lobsters",
            feedURL: URL(static: "https://lobste.rs/rss"),
            defaultTopics: [.web, .backend, .product]),
        RSSFeedDefinition(
            sourceName: "Stripe Engineering",
            feedURL: URL(static: "https://stripe.com/blog/feed.rss"),
            defaultTopics: [.backend, .product]),
        RSSFeedDefinition(
            sourceName: "Netflix Tech Blog",
            feedURL: URL(static: "https://netflixtechblog.com/feed"),
            defaultTopics: [.backend, .ai]),
        RSSFeedDefinition(
            sourceName: "High Scalability",
            feedURL: URL(static: "https://www.highscalability.com/feed"),
            defaultTopics: [.backend]),
        RSSFeedDefinition(
            sourceName: "Stack Overflow Blog",
            feedURL: URL(static: "https://stackoverflow.blog/feed/"),
            defaultTopics: [.product, .backend]),
        RSSFeedDefinition(
            sourceName: "CSS-Tricks",
            feedURL: URL(static: "https://css-tricks.com/feed/"),
            defaultTopics: [.web]),
        RSSFeedDefinition(
            sourceName: "Hacking with Swift",
            feedURL: URL(static: "https://www.hackingwithswift.com/articles/rss"),
            defaultTopics: [.ios]),
        RSSFeedDefinition(
            sourceName: "Donny Wals",
            feedURL: URL(static: "https://www.donnywals.com/feed/"),
            defaultTopics: [.ios]),
        RSSFeedDefinition(
            sourceName: "Android Developers Blog",
            feedURL: URL(static: "https://android-developers.googleblog.com/feeds/posts/default"),
            defaultTopics: [.android]),
        RSSFeedDefinition(
            sourceName: "ProAndroidDev",
            feedURL: URL(static: "https://proandroiddev.com/feed"),
            defaultTopics: [.android]),
        RSSFeedDefinition(
            sourceName: "JetBrains Kotlin Blog",
            feedURL: URL(static: "https://blog.jetbrains.com/kotlin/feed/"),
            defaultTopics: [.android]),
        RSSFeedDefinition(
            sourceName: "Apple Developer News",
            feedURL: URL(static: "https://developer.apple.com/news/rss/news.rss"),
            defaultTopics: [.ios]),
        RSSFeedDefinition(
            sourceName: "NSHipster",
            feedURL: URL(static: "https://nshipster.com/feed.xml"),
            defaultTopics: [.ios]),
        RSSFeedDefinition(
            sourceName: "SwiftLee",
            feedURL: URL(static: "https://www.avanderlee.com/feed/"),
            defaultTopics: [.ios]),
        RSSFeedDefinition(
            sourceName: "Hugging Face",
            feedURL: URL(static: "https://huggingface.co/blog/feed.xml"),
            defaultTopics: [.ai]),
        RSSFeedDefinition(
            sourceName: "Simon Willison",
            feedURL: URL(static: "https://simonwillison.net/atom/everything/"),
            defaultTopics: [.ai, .backend]),
        RSSFeedDefinition(
            sourceName: "Dropbox Tech",
            feedURL: URL(static: "https://dropbox.tech/feed"),
            defaultTopics: [.backend]),
        RSSFeedDefinition(
            sourceName: "Spotify Engineering",
            feedURL: URL(static: "https://engineering.atspotify.com/feed"),
            defaultTopics: [.backend, .ai]),
        RSSFeedDefinition(
            sourceName: "Vercel",
            feedURL: URL(static: "https://vercel.com/atom"),
            defaultTopics: [.web, .product]),
        RSSFeedDefinition(
            sourceName: "Julia Evans",
            feedURL: URL(static: "https://jvns.ca/atom.xml"),
            defaultTopics: [.backend, .security]),
        RSSFeedDefinition(
            sourceName: "Martin Fowler",
            feedURL: URL(static: "https://martinfowler.com/feed.atom"),
            defaultTopics: [.backend, .product]),
        RSSFeedDefinition(
            sourceName: "web.dev",
            feedURL: URL(static: "https://web.dev/feed.xml"),
            defaultTopics: [.web]),
        RSSFeedDefinition(
            sourceName: "Smashing Magazine",
            feedURL: URL(static: "https://www.smashingmagazine.com/feed/"),
            defaultTopics: [.web, .product]),
        RSSFeedDefinition(
            sourceName: "Krebs on Security",
            feedURL: URL(static: "https://krebsonsecurity.com/feed/"),
            defaultTopics: [.security]),
        RSSFeedDefinition(
            sourceName: "The Pragmatic Engineer",
            feedURL: URL(static: "https://newsletter.pragmaticengineer.com/feed"),
            defaultTopics: [.backend, .product]),
    ]
}

private struct ParsedRSSItem {
    let title: String
    let summary: String
    let link: URL
    let author: String?
    let publishedAt: Date
    let imageURL: URL?
}

private final class RSSFeedParser: NSObject, XMLParserDelegate {
    private enum Element: String {
        case item
        case entry
        case title
        case description
        case summary
        case content
        case encoded = "content:encoded"
        case link
        case author
        case name
        case creator = "dc:creator"
        case pubDate
        case published
        case updated
    }

    private static let itemElementNames: Set<String> = ["item", "entry"]

    private static let imageElementNames: Set<String> = [
        "media:thumbnail",
        "media:content",
        "enclosure"
    ]

    private struct PartialItem {
        var title = ""
        var description = ""
        var encodedContent = ""
        var link = ""
        var author = ""
        var publishedAt: Date?
        var imageURL: URL?
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

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String : String] = [:],
    ) {
        currentText = ""

        if Self.itemElementNames.contains(elementName) {
            currentItem = PartialItem()
        }

        if Self.imageElementNames.contains(elementName),
           var item = currentItem,
           item.imageURL == nil {
            if let candidate = imageURL(from: elementName, attributes: attributeDict) {
                item.imageURL = candidate
                currentItem = item
            }
        }

        if elementName == "link",
           var item = currentItem,
           let href = attributeDict["href"],
           !href.isEmpty {
            let rel = attributeDict["rel"] ?? "alternate"
            if rel == "alternate", item.link.isEmpty {
                item.link = href
                currentItem = item
            }
        }

        currentElement = Element(rawValue: elementName)
    }

    private func imageURL(
        from elementName: String,
        attributes: [String: String],
    ) -> URL? {
        if elementName == "enclosure" {
            guard let type = attributes["type"], type.hasPrefix("image/") else {
                return nil
            }
        }

        if elementName == "media:content" {
            if let medium = attributes["medium"], medium != "image" {
                return nil
            }
        }

        guard let raw = attributes["url"], let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String,
    ) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
    ) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var item = currentItem else {
            currentElement = nil
            currentText = ""
            return
        }

        if Self.itemElementNames.contains(elementName) {
            if
                let publishedAt = item.publishedAt,
                let link = URL(string: item.link),
                !item.title.isEmpty
            {
                let imageURL = item.imageURL
                    ?? firstImageURL(in: item.encodedContent)
                    ?? firstImageURL(in: item.description)

                let resolvedSummary = firstMeaningfulParagraph(in: item.encodedContent)
                    ?? sanitizedSummary(from: item.description)

                parsedItems.append(
                    ParsedRSSItem(
                        title: item.title,
                        summary: resolvedSummary,
                        link: link,
                        author: item.author.isEmpty ? nil : item.author,
                        publishedAt: publishedAt,
                        imageURL: imageURL))
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
            if item.description.isEmpty {
                item.description = trimmedText
            }
        case .summary:
            if item.description.isEmpty {
                item.description = trimmedText
            }
        case .content:
            if item.encodedContent.isEmpty {
                item.encodedContent = trimmedText
            }
        case .encoded:
            item.encodedContent = trimmedText
        case .link:
            if item.link.isEmpty {
                item.link = trimmedText
            }
        case .author, .creator:
            if item.author.isEmpty {
                item.author = trimmedText
            }
        case .name:
            if item.author.isEmpty {
                item.author = trimmedText
            }
        case .pubDate, .published, .updated:
            if item.publishedAt == nil {
                item.publishedAt = parsedDate(from: trimmedText)
            }
        case .item, .entry:
            break
        }

        currentItem = item
        self.currentElement = nil
        currentText = ""
    }

    private func parsedDate(from string: String) -> Date? {
        let rfcFormatters: [DateFormatter] = [
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

        for formatter in rfcFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]
        if let date = isoStandard.date(from: string) {
            return date
        }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: string) {
            return date
        }

        return nil
    }

    private func firstMeaningfulParagraph(in html: String) -> String? {
        guard !html.isEmpty else {
            return nil
        }

        let pattern = #"<p[^>]*>([\s\S]*?)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches {
            guard
                match.numberOfRanges >= 2,
                let inner = Range(match.range(at: 1), in: html)
            else {
                continue
            }
            let raw = String(html[inner])
            if isMeaningfulParagraph(raw) {
                return sanitizedSummary(from: raw)
            }
        }

        return nil
    }

    private func isMeaningfulParagraph(_ rawHTML: String) -> Bool {
        let cleaned = sanitizedSummary(from: rawHTML)
        guard cleaned.count >= 50 else {
            return false
        }

        let lowered = cleaned.lowercased()
        if lowered.hasPrefix("by ") {
            return false
        }
        if lowered == "comments" || lowered.hasPrefix("read more") || lowered.hasPrefix("continue reading") {
            return false
        }

        return true
    }

    private func firstImageURL(in html: String) -> URL? {
        guard !html.isEmpty else {
            return nil
        }

        let pattern = #"<img[^>]+src=["']([^"']+)["']"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
            match.numberOfRanges >= 2,
            let range = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        let raw = String(html[range])
        let decoded = raw
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        return URL(string: decoded)
    }

    private func sanitizedSummary(from rawHTML: String) -> String {
        let withoutTags = rawHTML.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression)

        let collapsedWhitespace = withoutTags.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression)

        return decodingHTMLEntities(collapsedWhitespace)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodingHTMLEntities(_ string: String) -> String {
        let named: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&hellip;", "…"),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&lsquo;", "‘"),
            ("&rsquo;", "’"),
            ("&ldquo;", "“"),
            ("&rdquo;", "”")
        ]
        var result = string
        for (entity, replacement) in named {
            if result.contains(entity) {
                result = result.replacingOccurrences(of: entity, with: replacement)
            }
        }

        result = decodingNumericEntities(result, prefix: "&#", radix: 10)
        result = decodingNumericEntities(result, prefix: "&#x", radix: 16)
        return result
    }

    private func decodingNumericEntities(
        _ string: String,
        prefix: String,
        radix: Int,
    ) -> String {
        let pattern: String
        switch radix {
        case 10: pattern = #"&#(\d+);"#
        case 16: pattern = #"&#x([0-9a-fA-F]+);"#
        default: return string
        }

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return string
        }

        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else {
            return string
        }

        var result = string
        for match in matches.reversed() {
            guard
                match.numberOfRanges >= 2,
                let codeRange = Range(match.range(at: 1), in: result),
                let code = Int(result[codeRange], radix: radix),
                let scalar = Unicode.Scalar(code),
                let fullRange = Range(match.range, in: result)
            else {
                continue
            }
            result.replaceSubrange(fullRange, with: String(Character(scalar)))
        }
        return result
    }
}
