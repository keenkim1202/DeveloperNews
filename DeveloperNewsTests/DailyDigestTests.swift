import Foundation
import Testing
@testable import DeveloperNews

// The digest is a local notification, so everything worth pinning is in how the
// toggle reacts to the system's answer and what text gets scheduled.
@MainActor
@Suite struct DailyDigestTests {
    private func makeState(
        notifications: MockNotificationScheduling,
        items: [ContentItem] = [],
    ) -> AppState {
        VMFixtures.makeAppState(
            notifications: notifications,
            contentSourceClient: StubContentSourceClient(items: items))
    }

    @Test func turningItOnAsksForPermissionAndSchedules() async {
        let notifications = MockNotificationScheduling()
        notifications.authorizationResult = .granted
        let state = makeState(notifications: notifications)

        await state.setNotificationsEnabled(true)

        #expect(notifications.requestCount == 1)
        #expect(state.notificationsEnabled)
        #expect(!state.notificationsDeniedBySystem)
        #expect(notifications.scheduledBodies.count == 1)
    }

    // A refused prompt must not leave a switch that looks on, because iOS will
    // not ask a second time and nothing would ever arrive.
    @Test func aRefusedPromptLeavesTheSettingOff() async {
        let notifications = MockNotificationScheduling()
        notifications.authorizationResult = .denied
        let state = makeState(notifications: notifications)

        await state.setNotificationsEnabled(true)

        #expect(!state.notificationsEnabled)
        #expect(state.notificationsDeniedBySystem)
        #expect(notifications.scheduledBodies.isEmpty)
    }

    @Test func turningItOffCancelsWithoutAsking() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)
        await state.setNotificationsEnabled(true)

        await state.setNotificationsEnabled(false)

        #expect(!state.notificationsEnabled)
        #expect(notifications.cancelCount >= 1)
        #expect(notifications.requestCount == 1)
    }

    @Test func theDigestCarriesTheTopStoryTitle() async {
        let notifications = MockNotificationScheduling()
        let item = VMFixtures.makeItem(title: "Swift 6.3 ships")
        let state = makeState(notifications: notifications, items: [item])
        state.selectedTopics = [.ios]
        await state.reload(notifyOnFailure: false)

        await state.setNotificationsEnabled(true)

        #expect(notifications.scheduledBodies.last == "Swift 6.3 ships")
    }

    // With no feed loaded there is no headline to promise, so the body falls
    // back rather than scheduling an empty notification.
    @Test func anEmptyFeedFallsBackToGenericText() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)

        await state.setNotificationsEnabled(true)

        #expect(notifications.scheduledBodies.last?.isEmpty == false)
    }

    @Test func refreshingTheDigestIsANoOpWhileTheSettingIsOff() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)

        await state.refreshDailyDigest()

        #expect(notifications.scheduledBodies.isEmpty)
    }

    // Permission revoked in the Settings app has to switch the setting back off
    // on the next launch, not leave it stranded on.
    @Test func permissionRevokedOutsideTheAppTurnsTheSettingOff() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)
        await state.setNotificationsEnabled(true)
        notifications.currentAuthorization = .denied

        await state.syncNotificationAuthorization()

        #expect(!state.notificationsEnabled)
        #expect(state.notificationsDeniedBySystem)
    }

    @Test func stillAuthorizedOnLaunchRearmsTheDigest() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)
        await state.setNotificationsEnabled(true)
        let scheduledOnEnable = notifications.scheduledBodies.count

        await state.syncNotificationAuthorization()

        #expect(state.notificationsEnabled)
        #expect(notifications.scheduledBodies.count == scheduledOnEnable + 1)
    }
}
