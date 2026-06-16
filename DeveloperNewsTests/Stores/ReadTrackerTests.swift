import XCTest
@testable import DeveloperNews

// Constructs ReadTracker directly with a no-op persist closure and exercises the
// read-marking queries plus the bounded eviction at the 5000-item cap.
@MainActor
final class ReadTrackerTests: XCTestCase {
    private func makeTracker() -> ReadTracker {
        ReadTracker(inputs: ReadTracker.Inputs(persistReadItems: { _, _ in }))
    }

    func testMarkAsReadThenIsRead() async {
        let tracker = makeTracker()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        XCTAssertFalse(tracker.isRead(item))
        tracker.markAsRead(item)
        XCTAssertTrue(tracker.isRead(item))
    }

    func testMarkURLAsReadMatchesContentItemHash() async {
        let tracker = makeTracker()
        let item = StoreTestSupport.makeItem(urlString: "https://example.com/a")

        tracker.markURLAsRead(item.url.absoluteString)

        XCTAssertTrue(tracker.isRead(item))
    }

    func testMarkPostAsReadThenIsPostRead() async {
        let tracker = makeTracker()

        XCTAssertFalse(tracker.isPostRead("post-1"))
        tracker.markPostAsRead("post-1")
        XCTAssertTrue(tracker.isPostRead("post-1"))
        XCTAssertFalse(tracker.isPostRead("post-2"))
    }

    func testTrimReadItemsEvictsAboveCap() async {
        let tracker = makeTracker()

        // Seed just over the cap; marking one more must trigger the trim.
        var seeded: Set<String> = []
        for index in 0..<5000 {
            seeded.insert(HashUtil.shortHash("https://example.com/seed/\(index)"))
        }
        tracker.seedInitialState(readItemURLs: seeded, readPostIds: [])
        XCTAssertEqual(tracker.readItemURLs.count, 5000)

        tracker.markURLAsRead("https://example.com/overflow")

        // Cap holds at 5000 after the new insert triggers eviction.
        XCTAssertEqual(tracker.readItemURLs.count, 5000)
    }

    func testTrimReadPostIdsEvictsAboveCap() async {
        let tracker = makeTracker()

        var seeded: Set<String> = []
        for index in 0..<5001 {
            seeded.insert(HashUtil.shortHash("post/\(index)"))
        }
        tracker.seedInitialState(readItemURLs: [], readPostIds: seeded)
        XCTAssertEqual(tracker.readPostIds.count, 5001)

        tracker.markPostAsRead("trigger-trim")

        XCTAssertEqual(tracker.readPostIds.count, 5000)
    }
}
