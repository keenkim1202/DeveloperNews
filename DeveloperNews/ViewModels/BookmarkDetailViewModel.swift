import Foundation
import Observation

@Observable
@MainActor
final class BookmarkDetailViewModel {
    private let appState: AppState
    private let item: ContentItem

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
    }

    var currentItem: ContentItem {
        appState.savedItemSnapshots[item.url] ?? item
    }

    func markCurrentAsRead() {
        appState.markAsRead(currentItem)
    }

    func deleteBookmark() {
        appState.removeSavedItem(at: currentItem.url)
    }
}
