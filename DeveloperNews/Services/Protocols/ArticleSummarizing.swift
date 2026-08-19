import Foundation

enum ArticleSummaryError: Error, Equatable {
    /// The device cannot run the model — unsupported hardware, Apple
    /// Intelligence switched off, or a region where it is not offered.
    case unavailable
    /// The page yielded too little text to summarize honestly.
    case notEnoughText
    case failed
}

/// Summarizes an article on device. No server, no API key, and nothing leaves
/// the phone — the same arrangement the translator already uses.
@MainActor
protocol ArticleSummarizing {
    /// False when the model cannot run here at all, which is permanent for the
    /// device rather than a transient failure.
    var isAvailable: Bool { get }

    /// A few short lines covering what the article says.
    func summarize(
        title: String,
        paragraphs: [String],
    ) async throws -> [String]
}
