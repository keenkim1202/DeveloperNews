import Foundation

/// A saved article's readable text, captured so it can still be read with no
/// network.
///
/// Text rather than an archive of the page: a few tens of kilobytes instead of
/// several megabytes, and the app already shows the real page when it can. This
/// is the fallback, not a replacement for it.
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
