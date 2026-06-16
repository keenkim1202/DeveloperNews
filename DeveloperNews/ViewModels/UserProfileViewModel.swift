import Foundation
import Observation

@Observable
@MainActor
final class UserProfileViewModel {
    private let appState: AppState
    private let authorId: String

    var followerCount = 0
    var followingCount = 0

    init(
        appState: AppState,
        authorId: String,
    ) {
        self.appState = appState
        self.authorId = authorId
    }

    var currentUserId: String? {
        appState.authService.userId
    }
    var isOwnProfile: Bool {
        currentUserId == authorId
    }
    var isFollowingAuthor: Bool {
        appState.profileService.isFollowing(authorId)
    }

    var authorPosts: [CommunityPost] {
        appState.communityService.posts.filter { $0.authorId == authorId }
    }

    func loadFollowCounts() async {
        followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
        followingCount = await appState.profileService.fetchFollowingCount(for: authorId)
    }

    func toggleFollow() async {
        await appState.profileService.toggleFollow(authorId)
        followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
    }
}
