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
        commentId: String? = nil,
        story: ActivityStory? = nil,
        preview: String = "Worth a read",
        isRead: Bool = false,
    ) -> Activity {
        Activity(
            id: id,
            kind: kind,
            actorId: actorId,
            target: target,
            commentId: commentId,
            story: story,
            parentCommentId: nil,
            preview: preview,
            createdAt: .now,
            isRead: isRead)
    }

    @Test func syncMarksEverythingReadAndKeepsTheOpeningHighlight() async {
        let activity = MockActivityServicing()
        activity.activities = [
            makeActivity(id: "a", isRead: false),
            makeActivity(id: "b", isRead: true),
        ]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.sync()

        #expect(activity.markAllAsReadCallCount == 1)
        #expect(vm.isUnread(activity.activities[0]))
        #expect(!vm.isUnread(activity.activities[1]))
        #expect(state.unreadActivityCount == 0)
    }

    // The listener is live, so the first snapshot can land after the screen is
    // already up. A sync that only ran once would leave those rows unread with
    // the badge lit, and their actors unresolved.
    @Test func syncHandlesActivitiesThatArriveAfterTheFirstRun() async {
        let profile = MockProfileServicing()
        let activity = MockActivityServicing()
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            profile: profile,
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.sync()
        #expect(state.unreadActivityCount == 0)

        profile.userSummaries = [
            UserSummary(id: "late", displayName: "Late", emoji: nil, bio: nil),
        ]
        activity.activities = [makeActivity(id: "late", actorId: "late", isRead: false)]
        await vm.sync()

        #expect(state.unreadActivityCount == 0)
        #expect(vm.isUnread(activity.activities[0]))
        #expect(vm.actor(for: activity.activities[0])?.displayName == "Late")
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

    // An actor whose account is gone resolves to nothing. Without remembering
    // the attempt, every sync would refetch them for as long as the row lives.
    @Test func anActorThatResolvesToNothingIsNotRefetched() async {
        let profile = MockProfileServicing()
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(actorId: "deleted")]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            profile: profile,
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.resolveActors()
        await vm.resolveActors()

        #expect(vm.actor(for: activity.activities[0]) == nil)
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

    // A comment activity opens the post scrolled to the comment it was about;
    // a like or a follow has no comment to point at.
    @Test func commentActivitiesCarryTheirCommentIntoTheDestination() {
        let state = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))
        let vm = ActivityViewModel(appState: state)

        #expect(
            vm.destination(for: makeActivity(
                kind: .commentReply, target: .feedPost("f1"), commentId: "c9"))
                == .feedPostDetail("f1", highlightedCommentId: "c9"))
        #expect(
            vm.destination(for: makeActivity(
                kind: .commentLike, target: .communityPost("c1"), commentId: "c9"))
                == .postDetail("c1", highlightedCommentId: "c9"))
        #expect(
            vm.destination(for: makeActivity(
                kind: .postLike, target: .feedPost("f1"), commentId: nil))
                == .feedPostDetail("f1", highlightedCommentId: nil))
    }

    // Hiding a blocked row is not enough: it still occupies one of the rows the
    // listener loads, so real notifications fall off the bottom.
    @Test func syncDeletesRowsFromBlockedActors() async {
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

        await vm.sync()

        #expect(activity.deletedActivityIds == [["a"]])
        #expect(activity.activities.map(\.id) == ["b"])
    }

    @Test func syncWithNothingBlockedDeletesNothing() async {
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a", actorId: "allowed")]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.sync()

        #expect(activity.deletedActivityIds.isEmpty)
    }

    @Test func deleteRemovesOnlyThatRow() async {
        let activity = MockActivityServicing()
        activity.activities = [
            makeActivity(id: "a"),
            makeActivity(id: "b"),
        ]
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.delete(activity.activities[0])

        #expect(activity.deletedActivityIds == [["a"]])
        #expect(vm.activities.map(\.id) == ["b"])
    }

    @Test func loadMoreIsOfferedOnlyWhileTheServiceHasMore() {
        let activity = MockActivityServicing()
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        #expect(!vm.canLoadMore)

        activity.canLoadMore = true
        #expect(vm.canLoadMore)

        vm.loadMore()
        #expect(activity.loadMoreCallCount == 1)
    }

    // The listener fails on its own schedule, with the screen closed and no
    // call in flight. Nothing else reports it, so the next sync has to — an
    // inbox left empty by a failed read must not read as an empty inbox.
    @Test func aListenerFailureIsReportedOnTheNextSync() async {
        let activity = MockActivityServicing()
        activity.errorMessage = "permission denied"
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.sync()
        #expect(state.toastTrigger == 1)
        #expect(state.toastMessage == "permission denied")

        await vm.sync()
        #expect(state.toastTrigger == 1)
    }

    // Shown once and not one sync longer: left in place, the same failure is
    // re-reported every time the screen syncs.
    @Test func aFailedDeleteIsReportedOnceAndNotAgain() async {
        let activity = MockActivityServicing()
        activity.activities = [makeActivity(id: "a")]
        activity.deleteFailureMessage = "could not reach the server"
        let state = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            activity: activity)
        let vm = ActivityViewModel(appState: state)

        await vm.delete(activity.activities[0])
        #expect(state.toastTrigger == 1)
        #expect(state.toastMessage == "could not reach the server")

        await vm.sync()
        #expect(state.toastTrigger == 1)
    }
}
