import Foundation
import Testing
@testable import DeveloperNews

// The number on the app icon comes from two places: the push sets it while the
// app is closed, and the inbox corrects it once the app is open. What is worth
// pinning is the correcting half, since it is the one that can disagree with
// what the reader sees on screen.
@MainActor
@Suite struct BadgeCountTests {
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
        let state = VMFixtures.makeAppState(activity: activity, notifications: notifications)

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
        let state = VMFixtures.makeAppState(activity: activity, notifications: notifications)
        state.blockUser("blocked")

        await state.refreshBadge()

        #expect(notifications.badgeCounts == [1])
    }

    @Test func signingOutClearsIt() async {
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        let notifications = MockNotificationScheduling()
        let state = VMFixtures.makeAppState(activity: activity, notifications: notifications)

        await state.signOut()

        #expect(notifications.badgeCounts == [0])
    }

    // An inbox that has not answered yet is an empty list, the same shape as an
    // inbox with nothing in it. Writing zero for the first would wipe a badge
    // the push had right.
    @Test func anInboxThatHasNotAnsweredIsNotACountOfZero() async {
        let activity = MockActivityServicing()
        activity.hasLoaded = false
        let notifications = MockNotificationScheduling()
        let state = VMFixtures.makeAppState(activity: activity, notifications: notifications)

        await state.refreshBadge()

        #expect(notifications.badgeCounts.isEmpty)
    }
}
