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
    private(set) var isResolvingActors = false

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

    func onAppear() async {
        unreadOnOpen = Set(activities.filter { !$0.isRead }.map(\.id))
        await resolveActors()
        await appState.activityService.markAllAsRead()
        if let message = appState.activityService.errorMessage {
            appState.presentError(message)
        }
    }

    /// Fills in the actors' current names and emoji. Activities store only an
    /// id, so this is what turns "someone" into a name.
    func resolveActors() async {
        let missing = Set(activities.map(\.actorId)).subtracting(actorsById.keys)
        guard !missing.isEmpty else {
            return
        }
        isResolvingActors = true
        defer { isResolvingActors = false }

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
                return .feedPostDetail(id)
            case let .communityPost(id):
                return .postDetail(id)
            case nil:
                return nil
            }
        }
    }
}
