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
}
