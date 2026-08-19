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

    /// Where the summary is in its lifecycle. Held per article, so reopening
    /// the sheet shows the summary already written rather than running the
    /// model again.
    enum SummaryState: Equatable {
        case idle
        case loading
        case ready([String])
        case failed(ArticleSummaryError)
    }

    private(set) var summaryState: SummaryState = .idle

    /// False when the model cannot run on this device at all. Permanent, so the
    /// entry point is hidden rather than offered and then refused.
    var isSummaryAvailable: Bool {
        appState.articleSummarizer.isAvailable
    }

    func summarize(paragraphs: [String]) async {
        if case .loading = summaryState {
            return
        }
        if case .ready = summaryState {
            return
        }

        summaryState = .loading
        do {
            let lines = try await appState.articleSummarizer.summarize(
                title: item.title,
                paragraphs: paragraphs)
            summaryState = .ready(lines)
        }
        catch let error as ArticleSummaryError {
            summaryState = .failed(error)
        }
        catch {
            summaryState = .failed(.failed)
        }
    }

    /// Drops a finished summary so the next request runs again, which is what
    /// the retry button needs.
    func resetSummary() {
        summaryState = .idle
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
    ) async throws -> [String: String] {
        let requests = chunk.map {
            TranslationSession.Request(
                sourceText: $0.text,
                clientIdentifier: String($0.id))
        }

        var translations: [String: String] = [:]
        // Throws rather than reporting an empty result, so the caller can tell
        // "this chunk had nothing to translate" apart from "the session is
        // gone" and stop instead of asking again.
        for try await response in session.translate(batch: requests) {
            if let id = response.clientIdentifier {
                translations[id] = response.targetText
            }
        }
        return translations
    }
}
