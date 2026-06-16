import XCTest
@testable import DeveloperNews

// Constructs SavedItemsStore directly with no-op persist closures and exercises
// the CRUD/toggle operations plus the two savedItems sort orders.
@MainActor
final class SavedItemsStoreTests: XCTestCase {
    private func makeStore(allItems: [ContentItem] = []) -> SavedItemsStore {
        SavedItemsStore(
            inputs: SavedItemsStore.Inputs(
                allItems: { allItems },
                personalizedItems: { [] },
                persistSavedItems: { _, _ in },
                persistSortOrder: { _ in }))
    }

    func testAddSavedItemMarksItemSaved() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        store.addSavedItem(item)

        XCTAssertTrue(store.isSaved(item))
        XCTAssertEqual(store.savedItems.count, 1)
        XCTAssertTrue(store.savedURLs.contains(item.url))
    }

    func testUpdateSavedItemReplacesSnapshotOnlyWhenPresent() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a", trendScore: 1)
        store.addSavedItem(item)

        let updated = StoreTestSupport.makeItem(urlString: "https://example.com/a", trendScore: 99)
        store.updateSavedItem(updated)

        XCTAssertEqual(store.savedItemSnapshots[item.url]?.trendScore, 99)

        // Updating an item that is not saved must be a no-op.
        let absent = StoreTestSupport.makeItem(urlString: "https://example.com/b", trendScore: 5)
        store.updateSavedItem(absent)
        XCTAssertNil(store.savedItemSnapshots[absent.url])
    }

    func testRemoveSavedItemClearsSnapshotAndTimestamp() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")
        store.addSavedItem(item)

        store.removeSavedItem(at: item.url)

        XCTAssertFalse(store.isSaved(item))
        XCTAssertNil(store.savedItemTimestampsByURL[item.url])
        XCTAssertTrue(store.savedItems.isEmpty)
    }

    func testToggleSavedAddsThenRemoves() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        store.toggleSaved(item)
        XCTAssertTrue(store.isSaved(item))

        store.toggleSaved(item)
        XCTAssertFalse(store.isSaved(item))
        XCTAssertNil(store.savedItemTimestampsByURL[item.url])
    }

    func testSavedItemIDsResolvesThroughAllItems() async {
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")
        let store = makeStore(allItems: [item])
        store.addSavedItem(item)

        XCTAssertEqual(store.savedItemIDs, Set([item.id]))
    }

    func testSavedItemsSortedByRecentlySaved() async {
        let store = makeStore()
        let older = StoreTestSupport.makeItem(urlString: "https://example.com/older")
        let newer = StoreTestSupport.makeItem(urlString: "https://example.com/newer")

        store.addSavedItem(older)
        // Force a strictly later timestamp for the second item.
        store.savedItemSnapshots[newer.url] = newer
        store.savedItemTimestampsByURL[older.url] = Date(timeIntervalSince1970: 1000)
        store.savedItemTimestampsByURL[newer.url] = Date(timeIntervalSince1970: 2000)

        store.setSavedSortOrder(.recentlySaved)

        XCTAssertEqual(store.savedItems.map(\.url), [newer.url, older.url])
    }

    func testSavedItemsSortedByTrendingThenPublishedAt() async {
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
        XCTAssertEqual(
            store.savedItems.map(\.url),
            [highNew.url, highOld.url, low.url])
    }
}
