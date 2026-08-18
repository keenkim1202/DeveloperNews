import Foundation
@testable import DeveloperNews

@MainActor
final class MockNotificationScheduling: NotificationScheduling {
    /// The answer `requestAuthorization()` resolves to, and what `authorization()`
    /// reports once a request has happened.
    var authorizationResult: NotificationAuthorization = .granted
    var currentAuthorization: NotificationAuthorization = .notDetermined

    private(set) var requestCount = 0
    private(set) var scheduledBodies: [String] = []
    private(set) var cancelCount = 0

    func authorization() async -> NotificationAuthorization {
        currentAuthorization
    }

    func requestAuthorization() async -> NotificationAuthorization {
        requestCount += 1
        currentAuthorization = authorizationResult
        return authorizationResult
    }

    func scheduleDailyDigest(body: String) async {
        scheduledBodies.append(body)
    }

    func cancelDailyDigest() {
        cancelCount += 1
    }
}
