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
    var authorName: String?
    var authorEmoji: String?
    // Separates "not fetched yet" from "fetched, and this user has no name": the
    // first renders blank, the second renders the unknown-user fallback.
    private(set) var hasLoadedProfile = false

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
            authorName = nonEmpty(appState.profileService.displayName)
            authorEmoji = nonEmpty(appState.profileService.profileEmoji)
        }
        else {
            let summaries = await appState.profileService.fetchUserSummaries(for: [authorId])
            let summary = summaries.first
            authorBio = summary?.bio
            authorName = nonEmpty(summary?.displayName)
            authorEmoji = nonEmpty(summary?.emoji)
        }
        hasLoadedProfile = true
    }

    private func nonEmpty(_ value: String?) -> String? {
        value.flatMap { $0.isEmpty ? nil : $0 }
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
