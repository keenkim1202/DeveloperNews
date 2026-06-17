import Foundation
import Observation

enum FollowListKind: Identifiable, Hashable {
    case followers
    case following

    var id: Self {
        self
    }
}

@Observable
@MainActor
final class FollowListViewModel {
    private let appState: AppState
    private let userId: String
    let kind: FollowListKind

    var summaries: [UserSummary] = []
    var isLoading = false

    init(
        appState: AppState,
        userId: String,
        kind: FollowListKind,
    ) {
        self.appState = appState
        self.userId = userId
        self.kind = kind
    }

    var currentUserId: String? {
        appState.authService.userId
    }

    func isFollowing(_ summaryId: String) -> Bool {
        appState.profileService.isFollowing(summaryId)
    }

    func load() async {
        isLoading = true
        switch kind {
        case .followers:
            summaries = await appState.profileService.fetchFollowers(of: userId)
        case .following:
            summaries = await appState.profileService.fetchFollowing(of: userId)
        }
        isLoading = false
        if let message = appState.profileService.errorMessage {
            appState.presentError(message)
        }
    }

    func toggleFollow(_ summaryId: String) async {
        await appState.profileService.toggleFollow(summaryId)
        if let message = appState.profileService.errorMessage {
            appState.presentError(message)
        }
    }
}
