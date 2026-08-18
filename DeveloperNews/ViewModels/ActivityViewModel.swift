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

    func isUnread(_ activity: Activity) -> Bool {
        unreadOnOpen.contains(activity.id)
    }

    func actor(for activity: Activity) -> UserSummary? {
        actorsById[activity.actorId]
    }

    /// Brings the screen up to date with whatever the listener currently holds.
    ///
    /// Called on appear and again on every change to the activity list, because
    /// the listener is live: its first snapshot can land after the screen is
    /// already up, and new activities arrive while the user is looking at it.
    /// Doing this once on appear left those rows unnamed and, worse, left them
    /// unread so the badge never cleared.
    func sync() async {
        // Recorded before the await so rows the user has actually seen keep
        // their highlight after everything is marked read, and extended rather
        // than replaced so a row that arrives mid-session is highlighted too.
        unreadOnOpen.formUnion(activities.filter { !$0.isRead }.map(\.id))
        await resolveActors()
        await appState.activityService.markAllAsRead()
        if let message = appState.activityService.errorMessage {
            appState.presentError(message)
        }
    }

    /// Fills in the actors' current names and emoji. Activities store only an
    /// id, so this is what turns "someone" into a name.
    ///
    /// Ids that resolve to nothing — a deleted account — are remembered as
    /// attempted so a repeating `sync` does not refetch them every time.
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
    func destination(for activity: Activity) -> CommunityTabDestination? {
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
