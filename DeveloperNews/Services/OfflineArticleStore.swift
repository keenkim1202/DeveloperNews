import Foundation
import Observation

/// Holds the captured text of saved articles.
///
/// Only saved articles are kept. Capturing everything opened would grow without
/// the reader ever asking for it, and bookmarking is the signal that something
/// is meant to be come back to.
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
    }

    func article(for url: URL) -> OfflineArticle? {
        articlesByURL[url]
    }

    func hasArticle(for url: URL) -> Bool {
        articlesByURL[url]?.isReadable ?? false
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
        trim()
        persist()
    }

    /// Drops the capture for an article that is no longer saved, so unsaving
    /// reclaims the space it was using.
    func removeArticle(for url: URL) {
        guard articlesByURL.removeValue(forKey: url) != nil else {
            return
        }
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
    }

    private func persist() {
        inputs.persistOfflineArticles(Array(articlesByURL.values))
    }
}
