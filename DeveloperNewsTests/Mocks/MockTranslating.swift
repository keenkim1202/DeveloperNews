import Foundation
import Translation
@testable import DeveloperNews

// Mock conformance to Translating returning canned values. Translation never
// runs in tests, so configuration is nil and the per-item lookups fall back to
// the item's own title and summary.
@MainActor
final class MockTranslating: Translating {
    var translatedTitles: [URL: String] = [:]
    var translatedSummaries: [URL: String] = [:]
    var targetLanguageCode: String?
    var canTranslate = false

    func makeConfiguration() -> TranslationSession.Configuration? {
        nil
    }

    func isTranslated(_ item: ContentItem) -> Bool {
        translatedTitles[item.url] != nil
    }

    func title(for item: ContentItem) -> String {
        translatedTitles[item.url] ?? item.title
    }

    func summary(for item: ContentItem) -> String {
        translatedSummaries[item.url] ?? item.summary
    }

    func translateSingle(
        _ item: ContentItem,
        using session: TranslationSession,
    ) async {
    }
}
