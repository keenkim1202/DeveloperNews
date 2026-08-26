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
    private(set) var scheduledTimes: [DigestTime] = []
    private(set) var cancelCount = 0

    func authorization() async -> NotificationAuthorization {
        currentAuthorization
    }

    func requestAuthorization() async -> NotificationAuthorization {
        requestCount += 1
        currentAuthorization = authorizationResult
        return authorizationResult
    }

    var scheduleSucceeds = true

    @discardableResult
    func scheduleDailyDigest(
        body: String,
        at time: DigestTime,
    ) async -> Bool {
        scheduledBodies.append(body)
        scheduledTimes.append(time)
        return scheduleSucceeds
    }

    func cancelDailyDigest() {
        cancelCount += 1
    }
}
