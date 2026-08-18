import Testing
import Foundation
@testable import DeveloperNews

// Constructs ReadTracker directly with a no-op persist closure and exercises the
// read-marking queries plus the bounded eviction at the 5000-item cap.
@MainActor
@Suite struct ReadTrackerTests {
    private func makeTracker() -> ReadTracker {
        ReadTracker(inputs: ReadTracker.Inputs(
            persistReadItems: { _, _ in },
            persistReadHistory: { _ in }))
    }

    @Test func markAsReadThenIsRead() async {
        let tracker = makeTracker()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        #expect(!tracker.isRead(item))
        tracker.markAsRead(item)
        #expect(tracker.isRead(item))
    }

    @Test func markURLAsReadMatchesContentItemHash() async {
        let tracker = makeTracker()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        tracker.markURLAsRead(item.url.absoluteString)

        #expect(tracker.isRead(item))
    }

    @Test func markPostAsReadThenIsPostRead() async {
        let tracker = makeTracker()

        #expect(!tracker.isPostRead("post-1"))
        tracker.markPostAsRead("post-1")
        #expect(tracker.isPostRead("post-1"))
        #expect(!tracker.isPostRead("post-2"))
    }

    @Test func trimReadItemsEvictsAboveCap() async {
        let tracker = makeTracker()

        // Seed just over the cap; marking one more must trigger the trim.
        var seeded: Set<String> = []
        for index in 0..<5000 {
            seeded.insert(HashUtil.shortHash("https://example.com/seed/\(index)"))
        }
        tracker.seedInitialState(readItemURLs: seeded, readPostIds: [])
        #expect(tracker.readItemURLs.count == 5000)

        tracker.markURLAsRead("https://example.com/overflow")

        // Cap holds at 5000 after the new insert triggers eviction.
        #expect(tracker.readItemURLs.count == 5000)
    }

    @Test func trimReadPostIdsEvictsAboveCap() async {
        let tracker = makeTracker()

        var seeded: Set<String> = []
        for index in 0..<5001 {
            seeded.insert(HashUtil.shortHash("post/\(index)"))
        }
        tracker.seedInitialState(readItemURLs: [], readPostIds: seeded)
        #expect(tracker.readPostIds.count == 5001)

        tracker.markPostAsRead("trigger-trim")

        #expect(tracker.readPostIds.count == 5000)
    }

    @Test func readingAnArticleRecordsItInHistory() {
        let tracker = makeTracker()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        tracker.markAsRead(item)

        #expect(tracker.readHistory.map(\.url) == [item.url])
        #expect(tracker.readHistory.first?.title == item.title)
    }

    // Re-reading should move an article back to the top rather than leave two
    // rows for the same URL.
    @Test func rereadingMovesTheEntryToTheTopWithoutDuplicating() {
        let tracker = makeTracker()
        let first = StoreTestSupport.makeItem(urlString: "https://example.com/a")
        let second = StoreTestSupport.makeItem(urlString: "https://example.com/b")

        tracker.markAsRead(first)
        tracker.markAsRead(second)
        tracker.markAsRead(first)

        #expect(tracker.readHistory.map(\.url) == [first.url, second.url])
    }

    @Test func historyIsCappedAndDropsTheOldestFirst() {
        let tracker = makeTracker()
        for index in 0 ..< 205 {
            tracker.markAsRead(
                StoreTestSupport.makeItem(urlString: "https://example.com/\(index)"))
        }

        #expect(tracker.readHistory.count == 200)
        #expect(tracker.readHistory.first?.url.absoluteString == "https://example.com/204")
        #expect(tracker.readHistory.last?.url.absoluteString == "https://example.com/5")
    }

    // Community posts route through markURLAsRead, which is read state only —
    // the history list is about articles.
    @Test func markingAURLReadDoesNotEnterHistory() {
        let tracker = makeTracker()

        tracker.markURLAsRead("devnews://community/post-1")

        #expect(tracker.readHistory.isEmpty)
    }

    @Test func clearingHistoryLeavesReadStateAlone() {
        let tracker = makeTracker()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")
        tracker.markAsRead(item)

        tracker.clearHistory()

        #expect(tracker.readHistory.isEmpty)
        #expect(tracker.isRead(item))
    }

    // History is the one piece of read state that has to survive a relaunch as
    // more than a hash, so the encode/decode round trip is worth pinning.
    @Test func historySurvivesAReloadThroughTheStore() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = PersistenceStore(defaults: defaults)
        let record = ReadRecord(
            url: URL(string: "https://example.com/a")!,
            title: "A story",
            sourceName: "Source",
            readAt: Date(timeIntervalSince1970: 1_000_000))

        await store.saveReadHistory([record])
        let reloaded = store.load().readHistory

        #expect(reloaded == [record])
    }
}
