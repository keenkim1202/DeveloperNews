import Foundation
import Testing
@testable import DeveloperNews

@MainActor
@Suite struct ActivityViewModelTests {
    private func makeActivity(
        id: String = UUID().uuidString,
        kind: ActivityKind = .postLike,
        actorId: String = "actor-1",
        target: ActivityTarget? = .feedPost("post-1"),
        preview: String = "Worth a read",
        isRead: Bool = false,
    ) -> Activity {
        Activity(
            id: id,
            kind: kind,
            actorId: actorId,
            target: target,
            preview: preview,
            createdAt: .now,
            isRead: isRead)
    }

    @Test func onAppearMarksEverythingReadAndKeepsTheOpeningHighlight() async {
        let activity = MockActivityServicing()
        activity.activities = [
            makeActivity(id: "a", isRead: false),
            makeActivity(id: "b", isRead: true),
        ]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.onAppear()

        #expect(activity.markAllAsReadCallCount == 1)
        #expect(vm.isUnread(activity.activities[0]))
        #expect(!vm.isUnread(activity.activities[1]))
        #expect(state.unreadActivityCount == 0)
    }

    @Test func blockedActorsAreHidden() {
        let activity = MockActivityServicing()
        activity.activities = [
            makeActivity(id: "a", actorId: "blocked"),
            makeActivity(id: "b", actorId: "allowed"),
        ]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        state.blockUser("blocked")
        let vm = ActivityViewModel(appState: state)

        #expect(vm.activities.map(\.id) == ["b"])
        #expect(state.unreadActivityCount == 1)
    }

    @Test func ownActionsAreHidden() {
        let activity = MockActivityServicing()
        activity.activities = [
            makeActivity(id: "a", actorId: "me"),
            makeActivity(id: "b", actorId: "someone"),
        ]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        #expect(vm.activities.map(\.id) == ["b"])
    }

    @Test func resolveActorsFillsInNamesOnce() async {
        let profile = MockProfileServicing()
        profile.userSummaries = [
            UserSummary(id: "actor-1", displayName: "Alice", emoji: "🐣", bio: nil),
        ]
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(actorId: "actor-1")]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            profile: profile,
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.resolveActors()
        await vm.resolveActors()

        #expect(vm.actor(for: activity.activities[0])?.displayName == "Alice")
        #expect(profile.requestedSummaryIds.count == 1)
    }

    @Test func destinationRoutesEachKindToItsScreen() {
        let state = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))
        let vm = ActivityViewModel(appState: state)

        #expect(
            vm.destination(for: makeActivity(kind: .follow, actorId: "actor-1", target: nil))
                == .userProfile(userId: "actor-1"))
        #expect(
            vm.destination(for: makeActivity(kind: .postComment, target: .feedPost("f1")))
                == .feedPostDetail("f1"))
        #expect(
            vm.destination(for: makeActivity(kind: .commentLike, target: .communityPost("c1")))
                == .postDetail("c1"))
        #expect(vm.destination(for: makeActivity(kind: .postLike, target: nil)) == nil)
    }
}
