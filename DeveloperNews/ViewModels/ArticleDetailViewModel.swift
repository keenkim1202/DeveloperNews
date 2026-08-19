import Foundation
import Observation
import Translation

@Observable
@MainActor
final class ArticleDetailViewModel {
    private let appState: AppState
    private let item: ContentItem

    var isTranslatingPage = false
    var isPageTranslated = false

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
    }

    private var translator: any Translating {
        appState.translator
    }

    var isSaved: Bool {
        appState.isSaved(item)
    }

    func toggleSaved() {
        appState.toggleSaved(item)
    }

    func markAsRead() {
        appState.markAsRead(item)
    }

    var currentNote: String {
        appState.savedItemSnapshots[item.url]?.summary ?? ""
    }

    var noteEditorItem: ContentItem {
        appState.savedItemSnapshots[item.url] ?? item
    }

    var canTranslate: Bool {
        translator.canTranslate
    }

    func makeTranslationConfiguration() -> TranslationSession.Configuration? {
        translator.makeConfiguration()
    }

    var offlineArticle: OfflineArticle? {
        appState.offlineArticle(for: item.url)
    }

    /// Only saved articles are captured, and only once — a page that has
    /// already been stored is not re-extracted on every visit.
    var shouldCaptureForOffline: Bool {
        appState.isSaved(item) && !appState.hasOfflineArticle(for: item.url)
    }

    func captureOfflineArticle(paragraphs: [String]) {
        appState.captureOfflineArticle(item, paragraphs: paragraphs)
    }

    var translationLanguageCode: String? {
        translator.targetLanguageCode
    }

    func setTranslationLanguage(_ code: String) {
        appState.setTranslationLanguage(code)
    }

    // Translates one chunk of extracted page text and returns the id-keyed
    // translations. The live web view JS extraction/injection stays in the view.
    func translateChunk(
        _ chunk: [PageTextEntry],
        using session: TranslationSession,
    ) async -> [String: String] {
        let requests = chunk.map {
            TranslationSession.Request(
                sourceText: $0.text,
                clientIdentifier: String($0.id))
        }

        var translations: [String: String] = [:]
        do {
            for try await response in session.translate(batch: requests) {
                if let id = response.clientIdentifier {
                    translations[id] = response.targetText
                }
            }
        }
        catch {
            return [:]
        }
        return translations
    }
}
