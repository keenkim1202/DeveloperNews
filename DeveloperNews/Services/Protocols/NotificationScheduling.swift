import Foundation

/// Outcome of asking for, or checking, permission to post notifications.
enum NotificationAuthorization: Sendable {
    case notDetermined
    case granted
    /// The user said no. iOS will not ask again, so the only way back is the
    /// Settings app.
    case denied
}

/// The daily digest is a local notification: it is scheduled on the device and
/// fires on the device, with no server and no push certificate involved.
@MainActor
protocol NotificationScheduling {
    func authorization() async -> NotificationAuthorization

    /// Prompts if permission has never been asked for; otherwise reports the
    /// standing answer without showing anything.
    func requestAuthorization() async -> NotificationAuthorization

    /// Replaces any previously scheduled digest with one carrying this body.
    /// Repeats daily at a fixed local hour.
    func scheduleDailyDigest(body: String) async

    func cancelDailyDigest()
}
