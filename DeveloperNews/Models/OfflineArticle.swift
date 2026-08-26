import Foundation

/// A saved article's readable text, kept so it opens with no network.
///
/// Text rather than an archive of the page — tens of kilobytes instead of
/// megabytes, and it is the fallback, not a second rendering of the site.
struct OfflineArticle: Identifiable, Hashable, Codable, Sendable {
    let url: URL
    let title: String
    let sourceName: String
    /// Block-level text in document order, already trimmed of empties.
    let paragraphs: [String]
    let capturedAt: Date

    var id: URL {
        url
    }

    var isReadable: Bool {
        !paragraphs.isEmpty
    }
}
