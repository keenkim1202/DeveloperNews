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

    // A pending notification keeps the hour it was scheduled with, so moving the
    // time has to replace the request rather than only store the new value.
    @Test func movingTheTimeRearmsTheDigest() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)
        await state.setNotificationsEnabled(true)
        #expect(notifications.scheduledTimes == [.default])

        await state.setDigestTime(DigestTime(minuteOfDay: 7 * 60 + 30))

        #expect(state.digestTime == DigestTime(minuteOfDay: 7 * 60 + 30))
        #expect(notifications.scheduledTimes.last == DigestTime(minuteOfDay: 7 * 60 + 30))
        #expect(state.notificationsEnabled)
    }

    // Rescheduling cancels the standing request before asking for the new one,
    // so a refusal leaves nothing pending. A switch left on would promise a
    // digest that cannot arrive.
    @Test func aRefusedRescheduleTurnsTheDigestOff() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)
        await state.setNotificationsEnabled(true)
        #expect(state.notificationsEnabled)

        notifications.scheduleSucceeds = false
        await state.setDigestTime(DigestTime(minuteOfDay: 7 * 60 + 30))

        #expect(!state.notificationsEnabled)
        #expect(state.toastMessage != nil)
        // The choice is still the reader's, so it survives for the next attempt.
        #expect(state.digestTime == DigestTime(minuteOfDay: 7 * 60 + 30))
    }

    // With the digest off there is nothing to re-arm, but the choice is still
    // the reader's and has to survive until they turn it on.
    @Test func theTimeIsKeptWhileTheDigestIsOff() async {
        let notifications = MockNotificationScheduling()
        let state = makeState(notifications: notifications)

        await state.setDigestTime(DigestTime(minuteOfDay: 22 * 60))

        #expect(state.digestTime == DigestTime(minuteOfDay: 22 * 60))
        #expect(notifications.scheduledTimes.isEmpty)
        #expect(!state.notificationsEnabled)
    }
}
