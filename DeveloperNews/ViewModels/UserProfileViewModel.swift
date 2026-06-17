import Foundation
import Observation

@Observable
@MainActor
final class UserProfileViewModel {
    private let appState: AppState
    let authorId: String

    var followerCount = 0
    var followingCount = 0
    var authorFeedPosts: [FeedPost] = []
    var authorBio: String?

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

    func loadFeedPosts() async {
        let posts = await appState.feedPostService.fetchPosts(byAuthor: authorId)
        authorFeedPosts = posts.sorted { $0.createdAt > $1.createdAt }
        if let message = appState.feedPostService.errorMessage {
            appState.presentError(message)
        }
    }

    func loadBio() async {
        if isOwnProfile {
            authorBio = appState.profileService.profileBio
        }
        else {
            let summaries = await appState.profileService.fetchUserSummaries(for: [authorId])
            authorBio = summaries.first?.bio
        }
    }

    func loadFollowCounts() async {
        followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
        followingCount = await appState.profileService.fetchFollowingCount(for: authorId)
        if let message = appState.profileService.errorMessage {
            appState.presentError(message)
        }
    }

    func toggleFollow() async {
        await appState.profileService.toggleFollow(authorId)
        if let message = appState.profileService.errorMessage {
            appState.presentError(message)
        }
        followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
    }

    func blockAuthor() {
        appState.blockUser(authorId)
    }
}
