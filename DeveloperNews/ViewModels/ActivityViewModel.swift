import Foundation
import Observation

@Observable
@MainActor
final class ActivityViewModel {
    private let appState: AppState

    /// Ids that were still unread when the screen opened. The screen marks
    /// everything read on appear so the badge clears, so without this snapshot
    /// the highlight on the rows the user came to see would vanish under them.
    private(set) var unreadOnOpen: Set<Activity.ID> = []
    private(set) var actorsById: [String: UserSummary] = [:]

    /// Actor ids already looked up, resolved or not, so a lookup that came back
    /// empty is not retried on every sync.
    private var attemptedActorIds: Set<String> = []

    init(appState: AppState) {
        self.appState = appState
    }

    var activities: [Activity] {
        appState.visibleActivities
    }

    var isSignedIn: Bool {
        appState.authService.userId != nil
    }

    var isEmpty: Bool {
        activities.isEmpty
    }

    var canLoadMore: Bool {
        appState.activityService.canLoadMore
    }

    func loadMore() {
        appState.activityService.loadMore()
    }

    func isUnread(_ activity: Activity) -> Bool {
        unreadOnOpen.contains(activity.id)
    }

    func actor(for activity: Activity) -> UserSummary? {
        actorsById[activity.actorId]
    }

    /// Brings the screen up to date with whatever the listener holds. Runs on
    /// appear and on every change: the listener is live, and rows landing after
    /// the screen is up would otherwise stay unnamed and unread, badge still lit.
    func sync() async {
        // Recorded before the await so rows the user has actually seen keep
        // their highlight after everything is marked read, and extended rather
        // than replaced so a row that arrives mid-session is highlighted too.
        unreadOnOpen.formUnion(activities.filter { !$0.isRead }.map(\.id))
        await purgeBlockedActivities()
        await resolveActors()
        await appState.activityService.markAllAsRead()
        presentServiceError()
    }

    /// Shows the service's last failure once, then clears it. It may come from
    /// the call that just returned or from the listener, which fails with the
    /// screen closed; clearing is what stops it reappearing on every sync.
    private func presentServiceError() {
        guard let message = appState.activityService.errorMessage else {
            return
        }
        appState.presentError(message)
        appState.activityService.clearError()
    }

    /// Drops rows from a blocked actor. The list hides them, but a hidden row
    /// still occupies the window the listener loads, pushing real ones out.
    /// Blocking is local, so this runs on every sync, not once at block time.
    private func purgeBlockedActivities() async {
        let blockedIds = appState.activityService.activities
            .filter { appState.blockedUserIds.contains($0.actorId) }
            .map(\.id)
        guard !blockedIds.isEmpty else {
            return
        }
        await appState.activityService.delete(activityIds: blockedIds)
        presentServiceError()
    }

    func delete(_ activity: Activity) async {
        await appState.activityService.delete(activityIds: [activity.id])
        presentServiceError()
    }

    /// Fills in the actors' names and emoji — an activity stores only an id.
    /// An id that resolves to nothing (a deleted account) is remembered as
    /// attempted, so a repeating `sync` does not refetch it every time.
    func resolveActors() async {
        let missing = Set(activities.map(\.actorId)).subtracting(attemptedActorIds)
        guard !missing.isEmpty else {
            return
        }
        attemptedActorIds.formUnion(missing)
        let summaries = await appState.profileService.fetchUserSummaries(for: Array(missing))
        for summary in summaries {
            actorsById[summary.id] = summary
        }
    }

    /// Where tapping the row goes. Nil rows are not tappable — a post activity
    /// that lost its target has nothing to open.
    /// Where a tapped push opens. Anything that does not name a destination —
    /// a route dropped for being too large, a kind this build does not know —
    /// still came from the inbox, so the inbox is where the tap lands.
    static func destination(
        forPush payload: [String: String],
        blockedUserIds: Set<String>,
    ) -> CommunityTabDestination {
        guard let activity = ActivityDocument.activity(from: payload, id: ""),
              !blockedUserIds.contains(activity.actorId),
              let destination = destination(for: activity)
        else {
            return .activity
        }
        return destination
    }

    static func destination(for activity: Activity) -> CommunityTabDestination? {
        switch activity.kind {
        case .follow:
            return .userProfile(userId: activity.actorId)
        case .postLike, .postComment, .commentReply, .commentLike:
            switch activity.target {
            case let .feedPost(id):
                return .feedPostDetail(id, highlightedCommentId: activity.commentId)
            case let .communityPost(id):
                return .postDetail(id, highlightedCommentId: activity.commentId)
            case .story:
                // The engagement id is a URL hash, so the route is rebuilt from
                // the story copied onto the activity rather than from the id.
                guard let story = activity.story else {
                    return nil
                }
                return .storyDetail(
                    FeedPostStory(
                        url: story.url,
                        title: story.title,
                        sourceName: "",
                        sourceCategory: .article,
                        topics: [],
                        thumbnailURL: nil),
                    highlightedCommentId: activity.commentId)
            case nil:
                return nil
            }
        }
    }
}
