import Foundation

enum ArticleSummaryError: Error, Equatable {
    /// The device cannot run the model at all.
    case unavailable
    /// Apple Intelligence is off, which the reader can change.
    case appleIntelligenceOff
    /// The model is still downloading.
    case modelNotReady
    /// The page yielded too little text to summarize honestly.
    case notEnoughText
    case failed
}

/// Why summarizing is or is not possible right now.
///
/// The three unavailable cases are kept apart because what the reader can do
/// about them differs completely: one is a switch they can flip, one resolves
/// itself, and one never will. Collapsing them into a single "unavailable"
/// throws away the only information worth telling them.
enum SummaryAvailability: Equatable {
    case available
    /// Apple Intelligence is switched off. The reader can turn it on.
    case appleIntelligenceOff
    /// The model is still downloading. It will work shortly.
    case modelNotReady
    /// The hardware cannot run it. Nothing will change that.
    case deviceNotEligible
}

/// Summarizes an article on device. No server, no API key, and nothing leaves
/// the phone — the same arrangement the translator already uses.
@MainActor
protocol ArticleSummarizing {
    var availability: SummaryAvailability { get }

    /// A few short lines covering what the article says.
    func summarize(
        title: String,
        paragraphs: [String],
    ) async throws -> [String]
}
