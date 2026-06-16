import Foundation
import Observation

// Owns the read-tracking subsystem: the short-hash sets of read article URLs
// and read community post ids, the mark operations, the read-state queries, and
// the bounded eviction that caps each set. Persistence is delegated back to
// AppState so writes keep flowing through its serial persistence chain. The
// closure avoids a retain cycle with AppState.
@Observable
@MainActor
final class ReadTracker {
    private static let maxReadItems = 5000

    private let inputs: Inputs

    var readItemURLs: Set<String> = []
    var readPostIds: Set<String> = []

    // Side effects supplied at init.
    struct Inputs {
        var persistReadItems: @MainActor (Set<String>, Set<String>) -> Void
    }

    init(inputs: Inputs) {
        self.inputs = inputs
    }

    func seedInitialState(
        readItemURLs: Set<String>,
        readPostIds: Set<String>,
    ) {
        self.readItemURLs = readItemURLs
        self.readPostIds = readPostIds
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
