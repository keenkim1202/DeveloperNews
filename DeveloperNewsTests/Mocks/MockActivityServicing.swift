import Foundation
@testable import DeveloperNews

@MainActor
final class MockActivityServicing: ActivityServicing {
    var activities: [Activity] = []
    var errorMessage: String?

    private(set) var listeningUserIds: [String] = []
    private(set) var didStopListening = false
    private(set) var markAllAsReadCallCount = 0
    private(set) var deletedInboxUserIds: [String] = []
    private(set) var deletedActivityIds: [[Activity.ID]] = []
    private(set) var loadMoreCallCount = 0
    var canLoadMore = false
    var hasLoaded = true
    var snapshotToken = 0
    var deleteInboxError: (any Error)?

    /// Set to make the next `delete` fail the way the live service does — with
    /// a message left on `errorMessage` rather than a thrown error.
    var deleteFailureMessage: String?

    func clearError() {
        errorMessage = nil
    }

    func startListening(userId: String) {
        listeningUserIds.append(userId)
    }

    func loadMore() {
        loadMoreCallCount += 1
    }

    func delete(activityIds: [Activity.ID]) async {
        deletedActivityIds.append(activityIds)
        if let deleteFailureMessage {
            errorMessage = deleteFailureMessage
            return
        }
        let removed = Set(activityIds)
        activities.removeAll { removed.contains($0.id) }
    }

    func stopListening() {
        didStopListening = true
        activities = []
    }

    func markAllAsRead() async {
        markAllAsReadCallCount += 1
        activities = activities.map { activity in
            Activity(
                id: activity.id,
                kind: activity.kind,
                actorId: activity.actorId,
                target: activity.target,
                commentId: activity.commentId,
                story: activity.story,
                parentCommentId: activity.parentCommentId,
                preview: activity.preview,
                createdAt: activity.createdAt,
                isRead: true)
        }
    }

    func deleteInbox(userId: String) async throws {
        deletedInboxUserIds.append(userId)
        if let deleteInboxError {
            throw deleteInboxError
        }
        activities = []
    }
}
