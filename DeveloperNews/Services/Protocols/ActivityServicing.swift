import Foundation

/// Read side of the activity inbox: the signed-in user's own recent activities
/// and the mark-as-read write that clears the unread badge.
@MainActor
protocol ActivityServicing {
    var activities: [Activity] { get }
    var errorMessage: String? { get }

    func startListening(userId: String)
    func stopListening()

    func markAllAsRead() async

    /// Deletes the user's whole inbox. Firestore does not remove a document's
    /// subcollections when the document goes, so account deletion has to clear
    /// this explicitly or the rows outlive their owner unreachable — the read
    /// rule keys on a uid that no longer signs in.
    func deleteInbox(userId: String) async throws
}
