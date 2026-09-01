import Foundation

/// Read side of the activity inbox: the signed-in user's own recent activities
/// and the mark-as-read write that clears the unread badge.
@MainActor
protocol ActivityServicing {
    var activities: [Activity] { get }
    var errorMessage: String? { get }

    /// Whether the inbox holds rows older than the ones currently loaded.
    var canLoadMore: Bool { get }

    /// Whether the server has answered yet. An empty inbox, one that has not
    /// answered, and one served from a stale cache all look the same in
    /// `activities`, and they are not the same thing.
    var hasServerSnapshot: Bool { get }

    /// Counts snapshots, so a listener that answers without changing anything
    /// is still something a caller can notice.
    var snapshotToken: Int { get }

    /// Drops the last failure once the screen has shown it.
    func clearError()

    func startListening(userId: String)
    func stopListening()

    /// Loads the next page of older rows on top of what is already loaded.
    func loadMore()

    func markAllAsRead() async

    /// Removes rows from the signed-in user's own inbox — one the reader swiped
    /// away, or a batch belonging to someone they have since blocked.
    func delete(activityIds: [Activity.ID]) async

    /// Deletes the user's whole inbox. Firestore leaves subcollections behind
    /// when a document goes, so account deletion has to clear this explicitly or
    /// the rows outlive their owner unreachable.
    func deleteInbox(userId: String) async throws
}
