import Foundation
import Observation

@Observable
@MainActor
final class SavedItemNoteComposerViewModel {
    private let appState: AppState
    private let item: ContentItem

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
    }

    func saveChanges(description: String) {
        guard let saved = appState.savedItemSnapshots[item.url] else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = ContentItem(
            id: saved.id,
            kind: saved.kind,
            title: saved.title,
            summary: trimmed,
            sourceName: saved.sourceName,
            sourceCategory: saved.sourceCategory,
            authorName: saved.authorName,
            url: saved.url,
            publishedAt: saved.publishedAt,
            topics: saved.topics,
            trendScore: saved.trendScore,
            thumbnailURL: saved.thumbnailURL,
            engagement: saved.engagement,
            isUserCreated: saved.isUserCreated,
            updatedAt: .now)
        appState.updateSavedItem(updated)
    }
}
