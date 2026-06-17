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
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        // Editing an existing bookmark updates its note in place; saving a story
        // that is not yet bookmarked creates it with the note in one step.
        let base = appState.savedItemSnapshots[item.url] ?? item
        let composed = ContentItem(
            id: base.id,
            kind: base.kind,
            title: base.title,
            summary: trimmed,
            sourceName: base.sourceName,
            sourceCategory: base.sourceCategory,
            authorName: base.authorName,
            url: base.url,
            publishedAt: base.publishedAt,
            topics: base.topics,
            trendScore: base.trendScore,
            thumbnailURL: base.thumbnailURL,
            engagement: base.engagement,
            isUserCreated: base.isUserCreated,
            updatedAt: .now)
        if appState.savedItemSnapshots[item.url] == nil {
            appState.addSavedItem(composed)
        }
        else {
            appState.updateSavedItem(composed)
        }
    }
}
