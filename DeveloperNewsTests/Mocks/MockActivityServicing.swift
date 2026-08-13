import Foundation
@testable import DeveloperNews

@MainActor
final class MockActivityServicing: ActivityServicing {
    var activities: [Activity] = []
    var errorMessage: String?

    private(set) var listeningUserIds: [String] = []
    private(set) var didStopListening = false
    private(set) var markAllAsReadCallCount = 0

    func startListening(userId: String) {
        listeningUserIds.append(userId)
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
                preview: activity.preview,
                createdAt: activity.createdAt,
                isRead: true)
        }
    }
}
