import FirebaseMessaging
import Foundation
import Observation
import UIKit

/// Pairs the device's push token with the signed-in reader, so a notification
/// written for that reader can reach this device.
///
/// The token comes from FCM whenever it issues or rotates one and the reader
/// from signing in, in either order. Nothing is written until both are known.
@Observable
@MainActor
final class PushRegistrar: NSObject, MessagingDelegate {
    private let store: any PushTokenStoring

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

    /// Starts listening for the token and asks iOS to register with APNs.
    ///
    /// Only worth asking for once notifications are permitted: APNs issues a
    /// token either way, but without permission nothing it delivers is shown.
    func start() async {
        Messaging.messaging().delegate = self
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

    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?,
    ) {
        Task { @MainActor in
            await tokenChanged(to: fcmToken)
        }
    }
}
