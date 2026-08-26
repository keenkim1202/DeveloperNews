import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler: NotificationScheduling {
    /// One identifier, reused every time, so re-scheduling replaces the pending
    /// request instead of stacking a second daily alert.
    static let dailyDigestIdentifier = "keen-onit.DeveloperNews.dailyDigest"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorization() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        return Self.mapping(settings.authorizationStatus)
    }

    func requestAuthorization() async -> NotificationAuthorization {
        let current = await authorization()
        // Asking again after a decision does not re-prompt, and requesting when
        // already denied returns false in a way indistinguishable from a fresh
        // refusal. Reporting the standing answer keeps those apart.
        guard current == .notDetermined else {
            return current
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .granted : .denied
        }
        catch {
            return .denied
        }
    }

    @discardableResult
    func scheduleDailyDigest(
        body: String,
        at time: DigestTime,
    ) async -> Bool {
        cancelDailyDigest()

        let content = UNMutableNotificationContent()
        content.title = String(localized: .notificationDailyDigestTitle)
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute

        let request = UNNotificationRequest(
            identifier: Self.dailyDigestIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))

        do {
            try await center.add(request)
            return true
        }
        catch {
            return false
        }
    }

    func cancelDailyDigest() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyDigestIdentifier])
    }

    private static func mapping(_ status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional, .ephemeral:
            .granted
        @unknown default:
            .denied
        }
    }
}
