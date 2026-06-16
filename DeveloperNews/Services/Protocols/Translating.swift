import Foundation
import Translation

@MainActor
protocol Translating {
    var translatedTitles: [URL: String] { get }
    var translatedSummaries: [URL: String] { get }
    var targetLanguageCode: String? { get set }
    var canTranslate: Bool { get }

    func makeConfiguration() -> TranslationSession.Configuration?

    func isTranslated(_ item: ContentItem) -> Bool
    func title(for item: ContentItem) -> String
    func summary(for item: ContentItem) -> String

    func translateSingle(
        _ item: ContentItem,
        using session: TranslationSession,
    ) async
}
