import Foundation
import Observation

/// Holds the captured text of saved articles. Only saved ones: capturing
/// everything opened would grow without the reader ever asking for it, and
/// bookmarking is the signal that something is meant to be come back to.
@Observable
@MainActor
final class OfflineArticleStore {
    /// A cap on articles rather than bytes: each is small, and a count is
    /// something a reader could reason about if it were ever surfaced.
    static let maxArticles = 100

    /// Paragraphs past this are dropped. Long enough for any article, short
    /// enough that a runaway page cannot fill the store on its own.
    static let maxParagraphs = 400

    private let inputs: Inputs

    private(set) var articlesByURL: [URL: OfflineArticle] = [:]

    /// How much of a capture is searchable. The extractor allows 5,000
    /// characters a block and this store 400 blocks, so an unbounded index
    /// could hold two hundred million. Past this an article's tail is missed.
    private static let maxSearchTextBytes = 20_000

    /// Lowercased body text, built on the first search that needs it — search
    /// runs on every keystroke. Not observed: it fills during a view body
    /// evaluation, where an observed write re-renders the view that caused it.
    @ObservationIgnored
    private var searchTextByURL: [URL: String] = [:]

    struct Inputs {
        var persistOfflineArticles: @MainActor ([OfflineArticle]) -> Void
    }

    init(inputs: Inputs) {
        self.inputs = inputs
    }

    func seedInitialState(_ articles: [OfflineArticle]) {
        articlesByURL = Dictionary(
            articles.map { ($0.url, $0) },
            uniquingKeysWith: { first, _ in first })
        searchTextByURL = [:]
    }

    func article(for url: URL) -> OfflineArticle? {
        articlesByURL[url]
    }

    func hasArticle(for url: URL) -> Bool {
        articlesByURL[url]?.isReadable ?? false
    }

    /// Whether the captured text contains `needle`, which the caller has
    /// already lowercased. The text is on the device for offline reading either
    /// way; without this a saved article is findable only by its title.
    func bodyContains(_ needle: String, url: URL) -> Bool {
        guard let text = searchText(for: url) else {
            return false
        }
        return text.contains(needle)
    }

    private func searchText(for url: URL) -> String? {
        if let cached = searchTextByURL[url] {
            return cached
        }
        guard let article = articlesByURL[url] else {
            return nil
        }
        // Built a block at a time rather than joined and then trimmed, so the
        // whole capture is never materialised at once. The result can overrun
        // the budget by the last block it took, which the block cap bounds.
        var text = ""
        for paragraph in article.paragraphs {
            text += paragraph.lowercased()
            text += " "
            if text.utf8.count >= Self.maxSearchTextBytes {
                break
            }
        }
        searchTextByURL[url] = text
        return text
    }

    /// Stores a capture, replacing any earlier one for the same article so a
    /// re-read picks up a page that has since changed.
    func store(
        url: URL,
        title: String,
        sourceName: String,
        paragraphs: [String],
    ) {
        let cleaned = Array(
            paragraphs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(Self.maxParagraphs))
        guard !cleaned.isEmpty else {
            return
        }

        articlesByURL[url] = OfflineArticle(
            url: url,
            title: title,
            sourceName: sourceName,
            paragraphs: cleaned,
            capturedAt: .now)
        searchTextByURL[url] = nil
        trim()
        persist()
    }

    /// Drops the capture for an article that is no longer saved, so unsaving
    /// reclaims the space it was using.
    func removeArticle(for url: URL) {
        guard articlesByURL.removeValue(forKey: url) != nil else {
            return
        }
        searchTextByURL[url] = nil
        persist()
    }

    private func trim() {
        guard articlesByURL.count > Self.maxArticles else {
            return
        }
        let keep = articlesByURL.values
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(Self.maxArticles)
        articlesByURL = Dictionary(
            keep.map { ($0.url, $0) },
            uniquingKeysWith: { first, _ in first })
        searchTextByURL = searchTextByURL.filter { articlesByURL[$0.key] != nil }
    }

    private func persist() {
        inputs.persistOfflineArticles(Array(articlesByURL.values))
    }
}
