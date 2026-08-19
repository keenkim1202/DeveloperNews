import Foundation
@testable import DeveloperNews

@MainActor
final class MockArticleSummarizing: ArticleSummarizing {
    var availability: SummaryAvailability = .available
    /// What `summarize` resolves to. Defaults to a usable summary so a test
    /// only has to set this when it cares about the failure paths.
    var result: Result<[String], ArticleSummaryError> = .success(["First point", "Second point"])

    private(set) var requests: [(title: String, paragraphs: [String])] = []

    func summarize(
        title: String,
        paragraphs: [String],
    ) async throws -> [String] {
        requests.append((title, paragraphs))
        return try result.get()
    }
}
