import FirebaseCore
import FirebaseMessaging
import Foundation
import UserNotifications
import Observation
import UIKit

/// Pairs the device's push token with the signed-in reader, so a notification
/// written for that reader can reach this device.
///
/// The token comes from FCM whenever it issues or rotates one and the reader
/// from signing in, in either order. Nothing is written until both are known.
@Observable
@MainActor
final class PushRegistrar: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    private let store: any PushTokenStoring

    /// What a tapped notification points at. Set by whoever can navigate.
    @ObservationIgnored
    var onTap: ((CommunityTabDestination) -> Void)?

    @ObservationIgnored
    private var token: String?
    @ObservationIgnored
    private var userId: String?

    /// Whether the reader currently wants alerts. A token that arrives while
    /// this is false is remembered but not written: the switch being off has to
    /// mean nothing reaches the device, and iOS keeps its permission either way.
    @ObservationIgnored
    private var isEnabled = false

    init(store: any PushTokenStoring = PushTokenStore()) {
        self.store = store
        super.init()
    }

    /// Claims the two callbacks that only arrive once, and only to whoever is
    /// listening when they do: the FCM token, and the tap on a notification
    /// that launched the app. Both land before any screen exists, so this has
    /// to run while the app is still starting up.
    func installDelegates() {
        UNUserNotificationCenter.current().delegate = self
        // A checkout without GoogleService-Info.plist runs with the community
        // signed out, and asking Messaging for its instance there would take
        // the launch down with it.
        guard FirebaseApp.app() != nil else {
            return
        }
        Messaging.messaging().delegate = self
    }

    /// Asks iOS to register with APNs.
    ///
    /// Only worth asking for once notifications are permitted: APNs issues a
    /// token either way, but without permission nothing it delivers is shown.
    func start() async {
        UIApplication.shared.registerForRemoteNotifications()
        await setEnabled(true)
    }

    /// Unpairs this device and stops it receiving anything. Must run while the
    /// reader is still signed in — the rule allows a delete only from the
    /// token's owner, so a later attempt is refused and the row survives.
    func stop() async {
        await setEnabled(false)
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    /// The pairing half of `start` and `stop`, without the APNs and FCM calls
    /// wrapped around it — those need a configured Firebase and a real
    /// application, neither of which a test has.
    func setEnabled(_ isEnabled: Bool) async {
        self.isEnabled = isEnabled
        guard isEnabled else {
            if let token, let userId {
                await store.remove(token, userId: userId)
            }
            return
        }
        await saveIfPaired()
    }

    func userChanged(to userId: String?) async {
        guard self.userId != userId else {
            return
        }
        if let previous = self.userId, let token {
            await store.remove(token, userId: previous)
        }
        self.userId = userId
        await saveIfPaired()
    }

    func tokenChanged(to token: String?) async {
        guard self.token != token else {
            return
        }
        if let previous = self.token, let userId {
            await store.remove(previous, userId: userId)
        }
        self.token = token
        await saveIfPaired()
    }

    private func saveIfPaired() async {
        guard isEnabled, let token, let userId else {
            return
        }
        await store.save(token, userId: userId)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
    ) async {
        // Flattened to strings here: the userInfo dictionary itself cannot
        // cross to the main actor, and strings are all the route is made of.
        let payload = response.notification.request.content.userInfo
            .reduce(into: [String: String]()) { result, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    result[key] = value
                }
            }
        await MainActor.run {
            onTap?(ActivityViewModel.destination(forPush: payload))
        }
    }

    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?,
    ) {
        Task { @MainActor in
            await tokenChanged(to: fcmToken)
        }
    }
}
