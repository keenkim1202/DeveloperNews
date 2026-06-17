import Testing
import Foundation
@testable import DeveloperNews

// Constructs SavedItemsStore directly with no-op persist closures and exercises
// the CRUD/toggle operations plus the two savedItems sort orders.
@MainActor
@Suite struct SavedItemsStoreTests {
    private func makeStore(allItems: [ContentItem] = []) -> SavedItemsStore {
        SavedItemsStore(
            inputs: SavedItemsStore.Inputs(
                allItems: { allItems },
                personalizedItems: { [] },
                persistSavedItems: { _, _ in },
                persistSortOrder: { _ in }))
    }

    @Test func addSavedItemMarksItemSaved() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        store.addSavedItem(item)

        #expect(store.isSaved(item))
        #expect(store.savedItems.count == 1)
        #expect(store.savedURLs.contains(item.url))
    }

    @Test func updateSavedItemReplacesSnapshotOnlyWhenPresent() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a", trendScore: 1)
        store.addSavedItem(item)

        let updated = StoreTestSupport.makeItem(urlString: "https://example.com/a", trendScore: 99)
        store.updateSavedItem(updated)

        #expect(store.savedItemSnapshots[item.url]?.trendScore == 99)

        // Updating an item that is not saved must be a no-op.
        let absent = StoreTestSupport.makeItem(urlString: "https://example.com/b", trendScore: 5)
        store.updateSavedItem(absent)
        #expect(store.savedItemSnapshots[absent.url] == nil)
    }

    @Test func removeSavedItemClearsSnapshotAndTimestamp() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")
        store.addSavedItem(item)

        store.removeSavedItem(at: item.url)

        #expect(!store.isSaved(item))
        #expect(store.savedItemTimestampsByURL[item.url] == nil)
        #expect(store.savedItems.isEmpty)
    }

    @Test func toggleSavedAddsThenRemoves() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        store.toggleSaved(item)
        #expect(store.isSaved(item))

        store.toggleSaved(item)
        #expect(!store.isSaved(item))
        #expect(store.savedItemTimestampsByURL[item.url] == nil)
    }

    @Test func savedItemIDsResolvesThroughAllItems() async {
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")
        let store = makeStore(allItems: [item])
        store.addSavedItem(item)

        #expect(store.savedItemIDs == Set([item.id]))
    }

    @Test func savedItemsSortedByRecentlySaved() async {
        let store = makeStore()
        let older = StoreTestSupport.makeItem(urlString: "https://example.com/older")
        let newer = StoreTestSupport.makeItem(urlString: "https://example.com/newer")

        store.addSavedItem(older)
        // Force a strictly later timestamp for the second item.
        store.savedItemSnapshots[newer.url] = newer
        store.savedItemTimestampsByURL[older.url] = Date(timeIntervalSince1970: 1000)
        store.savedItemTimestampsByURL[newer.url] = Date(timeIntervalSince1970: 2000)

        store.setSavedSortOrder(.recentlySaved)

        #expect(store.savedItems.map(\.url) == [newer.url, older.url])
    }

    @Test func savedItemsSortedByTrendingThenPublishedAt() async {
        let store = makeStore()
        let low = StoreTestSupport.makeItem(
            urlString: "https://example.com/low",
            trendScore: 10,
            publishedAt: Date(timeIntervalSince1970: 5000))
        let highOld = StoreTestSupport.makeItem(
            urlString: "https://example.com/high-old",
            trendScore: 90,
            publishedAt: Date(timeIntervalSince1970: 1000))
        let highNew = StoreTestSupport.makeItem(
            urlString: "https://example.com/high-new",
            trendScore: 90,
            publishedAt: Date(timeIntervalSince1970: 9000))

        store.addSavedItem(low)
        store.addSavedItem(highOld)
        store.addSavedItem(highNew)

        store.setSavedSortOrder(.trending)

        // Higher trendScore first; within equal scores, newer publishedAt first.
        #expect(store.savedItems.map(\.url) == [highNew.url, highOld.url, low.url])
    }
}
