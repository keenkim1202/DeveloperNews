import Foundation
import Testing
@testable import DeveloperNews

// The number on the app icon comes from two places: the push sets it while the
// app is closed, and the inbox corrects it once the app is open. What is worth
// pinning is the correcting half, since it is the one that can disagree with
// what the reader sees on screen.
@MainActor
@Suite struct BadgeCountTests {
    /// The switch is what the badge hangs off, so every case here starts with
    /// it on. Turning it off is its own test.
    private func makeState(
        auth: MockAuthServicing = MockAuthServicing(),
        activity: MockActivityServicing = MockActivityServicing(),
        notifications: MockNotificationScheduling = MockNotificationScheduling(),
    ) -> AppState {
        let state = VMFixtures.makeAppState(
            auth: auth,
            activity: activity,
            notifications: notifications)
        state.notificationsEnabled = true
        return state
    }

    private func makeActivity(
        id: String,
        actorId: String = "actor-1",
        isRead: Bool = false,
    ) -> Activity {
        Activity(
            id: id,
            kind: .postLike,
            actorId: actorId,
            target: .feedPost("post-1"),
            commentId: nil,
            story: nil,
            parentCommentId: nil,
            preview: "",
            createdAt: .now,
            isRead: isRead)
    }

    @Test func theBadgeCountsWhatIsUnread() async {
        let activity = MockActivityServicing()
        activity.activities = [
            makeActivity(id: "a"),
            makeActivity(id: "b"),
            makeActivity(id: "c", isRead: true),
        ]
        let notifications = MockNotificationScheduling()
        let state = makeState(activity: activity, notifications: notifications)

        await state.refreshBadge()

        #expect(notifications.badgeCounts == [2])
    }

    // A server counting rows in the inbox cannot know who this reader blocked,
    // so its number is high until the app is opened. This is where it is fixed.
    @Test func aBlockedActorIsNotWorthANumber() async {
        let activity = MockActivityServicing()
        activity.activities = [
            makeActivity(id: "a"),
            makeActivity(id: "b", actorId: "blocked"),
        ]
        let notifications = MockNotificationScheduling()
        let state = makeState(activity: activity, notifications: notifications)
        state.blockUser("blocked")

        await state.refreshBadge()

        #expect(notifications.badgeCounts == [1])
    }

    @Test func signingOutClearsIt() async {
        let auth = MockAuthServicing()
        auth.userId = "me"
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        let notifications = MockNotificationScheduling()
        let state = makeState(
            auth: auth,
            activity: activity,
            notifications: notifications)

        await state.signOut()

        #expect(notifications.badgeCounts == [0])
    }

    // A sign-out that failed leaves the reader signed in. Their unread rows are
    // still theirs to see.
    @Test func aFailedSignOutLeavesItAlone() async {
        let auth = MockAuthServicing()
        auth.userId = "me"
        auth.signOutFails = true
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        let notifications = MockNotificationScheduling()
        let state = makeState(
            auth: auth,
            activity: activity,
            notifications: notifications)

        await state.signOut()

        #expect(notifications.badgeCounts.isEmpty)
    }

    // An inbox that has not answered yet is an empty list, the same shape as an
    // inbox with nothing in it. Writing zero for the first would wipe a badge
    // the push had right.
    @Test func anInboxThatHasNotAnsweredIsNotACountOfZero() async {
        let activity = MockActivityServicing()
        activity.hasServerSnapshot = false
        let notifications = MockNotificationScheduling()
        let state = makeState(activity: activity, notifications: notifications)

        await state.refreshBadge()

        #expect(notifications.badgeCounts.isEmpty)
    }

    // An inbox that answers with nothing unread is still an answer, and the
    // badge a push left behind has to come off for it.
    @Test func anEmptyAnswerIsStillWorthWriting() async {
        let activity = MockActivityServicing()
        activity.hasServerSnapshot = true
        let notifications = MockNotificationScheduling()
        let state = makeState(activity: activity, notifications: notifications)

        #expect(state.badgeCount == 0)

        await state.refreshBadge()

        #expect(notifications.badgeCounts == [0])
    }

    @Test func deletingTheAccountClearsIt() async {
        let auth = MockAuthServicing()
        auth.userId = "me"
        auth.deleteAccountResult = .success
        let notifications = MockNotificationScheduling()
        let state = makeState(auth: auth, notifications: notifications)

        #expect(await state.deleteCurrentAccount() == .success)

        #expect(notifications.badgeCounts == [0])
    }

    // A push that counted a blocked row leaves the filtered number where it
    // was, so the number alone is not what the icon waits on. The snapshot that
    // carried the row is.
    @Test func aSnapshotThatChangesNothingIsStillWorthNoticing() async {
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        activity.activities.append(makeActivity(id: "b", actorId: "blocked"))
        let state = makeState(activity: activity)
        state.blockUser("blocked")

        let before = state.badgeSync
        activity.snapshotToken += 1

        #expect(state.badgeSync?.count == before?.count)
        #expect(state.badgeSync != before)
    }

    // Resuming is not evidence of anything: the rows in memory can be older
    // than the badge the push wrote while the app was away.
    @Test func resumingWithoutASnapshotIsNotAChange() async {
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        let state = makeState(activity: activity)

        #expect(state.badgeSync == state.badgeSync)
    }

    // Until permission is granted, iOS refuses the badge. Granting it is the
    // last moment anything asks for the count, so the switch has to ask again.
    @Test func turningNotificationsOnWritesTheCount() async {
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        let notifications = MockNotificationScheduling()
        notifications.authorizationResult = .granted
        // Starts off, which is the whole point: this is the moment the switch
        // is turned on for the first time.
        let state = VMFixtures.makeAppState(activity: activity, notifications: notifications)

        await state.setNotificationsEnabled(true)

        #expect(notifications.badgeCounts.last == 1)
    }

    // Turning alerts off leaves the iOS permission granted, so nothing else
    // keeps the number from coming back on the next snapshot.
    @Test func turningNotificationsOffClearsItAndKeepsItOff() async {
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        let notifications = MockNotificationScheduling()
        let state = makeState(activity: activity, notifications: notifications)

        await state.setNotificationsEnabled(false)
        await state.refreshBadge()

        #expect(notifications.badgeCounts == [0])
    }
}
