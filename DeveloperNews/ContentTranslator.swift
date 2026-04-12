import Foundation
import Translation

@Observable
final class ContentTranslator {
    private(set) var translatedTitles: [URL: String] = [:]
    private(set) var translatedSummaries: [URL: String] = [:]

    var targetLanguageCode: String? {
        didSet {
            if targetLanguageCode != oldValue {
                translatedTitles.removeAll()
                translatedSummaries.removeAll()
            }
        }
    }

    var canTranslate: Bool {
        targetLanguageCode != nil
    }

    func makeConfiguration() -> TranslationSession.Configuration? {
        guard let code = targetLanguageCode else { return nil }
        return .init(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: code)
        )
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

    func translateSingle(_ item: ContentItem, using session: TranslationSession) async {
        guard !isTranslated(item) else { return }

        var requests: [TranslationSession.Request] = [
            .init(sourceText: item.title, clientIdentifier: "t")
        ]
        if !item.summary.isEmpty {
            requests.append(.init(sourceText: item.summary, clientIdentifier: "s"))
        }

        do {
            for try await response in session.translate(batch: requests) {
                if response.clientIdentifier == "t" {
                    translatedTitles[item.url] = response.targetText
                }
                else if response.clientIdentifier == "s" {
                    translatedSummaries[item.url] = response.targetText
                }
            }
        }
        catch {
            // Translation failed — original text shown
        }
    }
}
