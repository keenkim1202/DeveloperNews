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
    private(set) var hasLoadedPosts = false

    /// Both sources of the author's identity have been tried. The unknown-user
    /// fallback waits for this rather than for `hasLoadedProfile` alone —
    /// otherwise a signed-out viewer, whose only source is the posts, reads
    /// "unknown user" and then watches it change into the real name.
    var hasResolvedIdentity: Bool {
        hasLoadedProfile && hasLoadedPosts
    }

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
        adoptAuthorIdentityFromPosts()
        hasLoadedPosts = true
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
            // Coalesce rather than assign: the summary is unavailable to a
            // signed-out viewer (firestore.rules restricts /users reads to
            // authenticated requests, and fetchUserSummaries turns that denial
            // into an empty array), and overwriting would discard the identity
            // adopted from this author's public posts.
            authorName = nonEmpty(summary?.displayName) ?? authorName
            authorEmoji = nonEmpty(summary?.emoji) ?? authorEmoji
        }
        hasLoadedProfile = true
    }

    /// Fills the author's name and emoji from their own public posts.
    ///
    /// `feedPosts` is world-readable while `/users` is not, so for a signed-out
    /// viewer this is the only identity available — without it every author
    /// opened from the public Discover feed renders as the unknown user.
    private func adoptAuthorIdentityFromPosts() {
        guard let newest = authorFeedPosts.first else {
            return
        }
        authorName = authorName ?? nonEmpty(newest.authorName)
        authorEmoji = authorEmoji ?? nonEmpty(newest.authorEmoji)
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
