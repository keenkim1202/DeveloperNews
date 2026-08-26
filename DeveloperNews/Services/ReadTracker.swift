import Foundation
import Observation

// Owns read state: short-hash sets of read article URLs and post ids, and the
// bounded eviction that caps them. Writes are delegated back to AppState so
// they keep their serial order. The
// closure avoids a retain cycle with AppState.
@Observable
@MainActor
final class ReadTracker {
    private static let maxReadItems = 5000

    /// History is a browsing aid, not an archive, so it keeps far fewer entries
    /// than the read-state hashes do — each one carries a title and a URL.
    private static let maxHistoryItems = 200

    private let inputs: Inputs

    var readItemURLs: Set<String> = []
    var readPostIds: Set<String> = []
    /// Newest first.
    private(set) var readHistory: [ReadRecord] = []

    // Side effects supplied at init.
    struct Inputs {
        var persistReadItems: @MainActor (Set<String>, Set<String>) -> Void
        var persistReadHistory: @MainActor ([ReadRecord]) -> Void
    }

    init(inputs: Inputs) {
        self.inputs = inputs
    }

    func seedInitialState(
        readItemURLs: Set<String>,
        readPostIds: Set<String>,
        readHistory: [ReadRecord] = [],
    ) {
        self.readItemURLs = readItemURLs
        self.readPostIds = readPostIds
        self.readHistory = readHistory
    }

    func markURLAsRead(_ urlString: String) {
        readItemURLs.insert(HashUtil.shortHash(urlString))
        trimReadItems()
        saveReadItems()
    }

    func markAsRead(_ item: ContentItem) {
        readItemURLs.insert(HashUtil.shortHash(item.url.absoluteString))
        trimReadItems()
        saveReadItems()
        recordInHistory(item)
    }

    func clearHistory() {
        readHistory = []
        inputs.persistReadHistory(readHistory)
    }

    /// Re-reading moves an article back to the top rather than adding a second
    /// row, so the list reads as "when I last saw this".
    private func recordInHistory(_ item: ContentItem) {
        let record = ReadRecord(
            url: item.url,
            title: item.title,
            sourceName: item.sourceName,
            readAt: .now)
        readHistory.removeAll { $0.url == item.url }
        readHistory.insert(record, at: 0)
        if readHistory.count > Self.maxHistoryItems {
            readHistory.removeLast(readHistory.count - Self.maxHistoryItems)
        }
        inputs.persistReadHistory(readHistory)
    }

    func isRead(_ item: ContentItem) -> Bool {
        readItemURLs.contains(HashUtil.shortHash(item.url.absoluteString))
    }

    func markPostAsRead(_ postId: String) {
        readPostIds.insert(HashUtil.shortHash(postId))
        trimReadItems()
        saveReadItems()
    }

    func isPostRead(_ postId: String) -> Bool {
        readPostIds.contains(HashUtil.shortHash(postId))
    }

    private func trimReadItems() {
        if readItemURLs.count > Self.maxReadItems {
            let excess = readItemURLs.count - Self.maxReadItems
            readItemURLs = Set(readItemURLs.dropFirst(excess))
        }
        if readPostIds.count > Self.maxReadItems {
            let excess = readPostIds.count - Self.maxReadItems
            readPostIds = Set(readPostIds.dropFirst(excess))
        }
    }

    private func saveReadItems() {
        inputs.persistReadItems(readItemURLs, readPostIds)
    }
}
