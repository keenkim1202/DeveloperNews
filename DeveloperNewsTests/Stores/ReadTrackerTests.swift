import Testing
import Foundation
@testable import DeveloperNews

// Constructs ReadTracker directly with a no-op persist closure and exercises the
// read-marking queries plus the bounded eviction at the 5000-item cap.
@MainActor
@Suite struct ReadTrackerTests {
    private func makeTracker() -> ReadTracker {
        ReadTracker(inputs: ReadTracker.Inputs(persistReadItems: { _, _ in }))
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
}
