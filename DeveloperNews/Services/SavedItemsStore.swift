import Foundation
import Observation

// Owns the saved-items subsystem: snapshots, save timestamps, sort order, and
// the CRUD/toggle operations over them. Feed-derived inputs that still live in
// AppState (all items, personalized feed) are read through closures, and
// persistence is delegated back to AppState so writes keep flowing through its
// serial persistence chain. Closures avoid a retain cycle with AppState.
@Observable
@MainActor
final class SavedItemsStore {
    private let inputs: Inputs

    var savedItemSnapshots: [URL: ContentItem] = [:]
    var savedItemTimestampsByURL: [URL: Date] = [:]
    var savedSortOrder: SavedSortOrder = .recentlySaved

    // Reads of AppState-owned inputs and side effects, supplied at init.
    struct Inputs {
        var allItems: @MainActor () -> [ContentItem]
        var personalizedItems: @MainActor () -> [ContentItem]
        var persistSavedItems: @MainActor ([URL: ContentItem], [URL: Date]) -> Void
        var persistSortOrder: @MainActor (SavedSortOrder) -> Void
    }

    init(inputs: Inputs) {
        self.inputs = inputs
    }

    func seedInitialState(
        snapshots: [URL: ContentItem],
        timestamps: [URL: Date],
        sortOrder: SavedSortOrder,
    ) {
        savedItemSnapshots = snapshots
        savedItemTimestampsByURL = timestamps
        savedSortOrder = sortOrder
    }

    var savedURLs: Set<URL> {
        Set(savedItemSnapshots.keys)
    }

    var savedItemIDs: Set<ContentItem.ID> {
        let urls = savedURLs
        return Set(inputs.allItems().filter { urls.contains($0.url) }.map(\.id))
    }

    func isSaved(_ item: ContentItem) -> Bool {
        savedItemSnapshots[item.url] != nil
    }

    var savedItems: [ContentItem] {
        let items = Array(savedItemSnapshots.values)
        switch savedSortOrder {
        case .recentlySaved:
            return items.sorted { lhs, rhs in
                let lhsDate = savedItemTimestampsByURL[lhs.url] ?? .distantPast
                let rhsDate = savedItemTimestampsByURL[rhs.url] ?? .distantPast
                return lhsDate > rhsDate
            }
        case .trending:
            return items.sorted { lhs, rhs in
                if lhs.trendScore == rhs.trendScore {
                    return lhs.publishedAt > rhs.publishedAt
                }
                return lhs.trendScore > rhs.trendScore
            }
        }
    }

    var savedArticleItems: [ContentItem] {
        savedItems.filter { $0.kind == .article }
    }

    var savedDiscussionItems: [ContentItem] {
        savedItems.filter { $0.kind == .discussion }
    }

    /// Looks up a `ContentItem` by url across saved items and personalized feed.
    /// URL is the stable identifier across app restarts (unlike `id`, which is regenerated per fetch).
    /// Returns nil if the item has been removed from both sources.
    func resolveItem(url: URL) -> ContentItem? {
        if let snapshot = savedItemSnapshots[url] {
            return snapshot
        }
        return inputs.personalizedItems().first { $0.url == url }
    }

    func addSavedItem(_ item: ContentItem) {
        savedItemSnapshots[item.url] = item
        savedItemTimestampsByURL[item.url] = .now
        saveSavedItems()
    }

    func updateSavedItem(_ item: ContentItem) {
        guard savedItemSnapshots[item.url] != nil else { return }
        savedItemSnapshots[item.url] = item
        saveSavedItems()
    }

    func removeSavedItem(at url: URL) {
        savedItemSnapshots[url] = nil
        savedItemTimestampsByURL[url] = nil
        saveSavedItems()
    }

    func toggleSaved(_ item: ContentItem) {
        if savedItemSnapshots[item.url] != nil {
            savedItemSnapshots[item.url] = nil
            savedItemTimestampsByURL[item.url] = nil
        }
        else {
            savedItemSnapshots[item.url] = item
            savedItemTimestampsByURL[item.url] = .now
        }

        saveSavedItems()
    }

    func setSavedSortOrder(_ order: SavedSortOrder) {
        guard savedSortOrder != order else {
            return
        }
        savedSortOrder = order
        saveSortOrder()
    }

    private func saveSavedItems() {
        inputs.persistSavedItems(savedItemSnapshots, savedItemTimestampsByURL)
    }

    private func saveSortOrder() {
        inputs.persistSortOrder(savedSortOrder)
    }
}
