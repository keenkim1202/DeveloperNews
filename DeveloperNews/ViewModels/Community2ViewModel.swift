import Foundation
import Observation

@Observable
@MainActor
final class Community2ViewModel {
    enum Mode: Hashable {
        case trending
        case recent
    }

    enum Tab: Hashable {
        case discover
        case following
    }

    private let appState: AppState

    private(set) var posts: [FeedPost] = []
    private(set) var followingPosts: [FeedPost] = []
    private(set) var isLoading = false
    private(set) var isLoadingFollowing = false
    private(set) var hasLoaded = false
    private(set) var hasLoadedFollowing = false
    private var loadedChangeToken = 0

    var tab: Tab = .discover
    var mode: Mode = .trending
    var searchQuery = ""

    private static let fetchLimit = 200

    init(appState: AppState) {
        self.appState = appState
    }

    var isSignedIn: Bool {
        appState.authService.isSignedIn
    }
    var hasNoPosts: Bool {
        visiblePosts.isEmpty
    }
    var hasNoFollowingPosts: Bool {
        visibleFollowingPosts.isEmpty
    }
    var displayedPosts: [FeedPost] {
        switch mode {
        case .trending:
            searchFiltered(trendingPosts)
        case .recent:
            searchFiltered(recentPosts)
        }
    }

    var displayedFollowingPosts: [FeedPost] {
        searchFiltered(visibleFollowingPosts)
    }

    var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Matches what a row actually shows: the quoted story and where it came
    /// from, what the poster said about it, and who they are.
    ///
    /// Only what has been fetched is searched. The feeds hold the most recent
    /// 200 posts, so this finds a post in the list rather than in the whole
    /// collection — a server-side search is a different piece of work.
    private func searchFiltered(_ posts: [FeedPost]) -> [FeedPost] {
        guard !trimmedQuery.isEmpty else {
            return posts
        }
        let needle = trimmedQuery.lowercased()
        return posts.filter {
            $0.story.title.lowercased().contains(needle)
                || $0.story.sourceName.lowercased().contains(needle)
                || $0.comment.lowercased().contains(needle)
                || $0.authorName.lowercased().contains(needle)
        }
    }

    var scrollToTopTrigger: Int {
        appState.communityScrollToTopTrigger
    }

    // Hide posts authored by blocked users from both feeds.
    private var visiblePosts: [FeedPost] {
        posts.filter { !appState.blockedUserIds.contains($0.authorId) }
    }

    var visibleFollowingPosts: [FeedPost] {
        followingPosts.filter { !appState.blockedUserIds.contains($0.authorId) }
    }

    var recentPosts: [FeedPost] {
        visiblePosts.sorted { $0.createdAt > $1.createdAt }
    }

    var trendingPosts: [FeedPost] {
        let now = Date()
        return visiblePosts.sorted { lhs, rhs in
            let lhsScore = Self.trendingScore(
                likeCount: lhs.likeCount,
                commentCount: lhs.commentCount,
                ageHours: now.timeIntervalSince(lhs.createdAt) / 3600)
            let rhsScore = Self.trendingScore(
                likeCount: rhs.likeCount,
                commentCount: rhs.commentCount,
                ageHours: now.timeIntervalSince(rhs.createdAt) / 3600)
            return lhsScore > rhsScore
        }
    }

    /// Time-decayed engagement ranking. Likes count once, comments are weighted
    /// double, and the score decays with the post's age so fresh content surfaces.
    static func trendingScore(
        likeCount: Int,
        commentCount: Int,
        ageHours: Double,
    ) -> Double {
        let engagement = Double(likeCount + 2 * commentCount)
        return (engagement + 1) / pow(max(0, ageHours) + 2, 1.5)
    }

    // Reload only when the discover feed has never loaded, or when a post was
    // created since the last load (possibly from another screen). Keeps tab
    // re-entry cheap while still surfacing a just-published post.
    func loadIfNeeded() async {
        if hasLoaded, loadedChangeToken == appState.feedPostService.changeToken {
            return
        }
        await load()
    }

    func load() async {
        guard !isLoading else {
            return
        }
        isLoading = true
        loadedChangeToken = appState.feedPostService.changeToken
        posts = await appState.feedPostService.fetchRecentPosts(limit: Self.fetchLimit)
        isLoading = false
        hasLoaded = true
    }

    func loadFollowing() async {
        guard !isLoadingFollowing else {
            return
        }
        isLoadingFollowing = true
        let authorIds = Array(appState.profileService.followedUserIds)
        if authorIds.isEmpty {
            followingPosts = []
        }
        else {
            followingPosts = await appState.feedPostService
                .fetchPosts(byAuthors: authorIds)
                .sorted { $0.createdAt > $1.createdAt }
        }
        isLoadingFollowing = false
        hasLoadedFollowing = true
    }

    func toggleLike(_ post: FeedPost) async {
        guard let userId = appState.authService.userId else {
            return
        }
        await appState.feedPostService.toggleLike(post, userId: userId)
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = Self.applyLikeToggle(posts[index], userId: userId)
        }
        if let index = followingPosts.firstIndex(where: { $0.id == post.id }) {
            followingPosts[index] = Self.applyLikeToggle(followingPosts[index], userId: userId)
        }
    }

    private static func applyLikeToggle(
        _ post: FeedPost,
        userId: String,
    ) -> FeedPost {
        var likedBy = post.likedBy
        let likeCount: Int
        if likedBy.contains(userId) {
            likedBy.remove(userId)
            likeCount = max(0, post.likeCount - 1)
        }
        else {
            likedBy.insert(userId)
            likeCount = post.likeCount + 1
        }
        return FeedPost(
            id: post.id,
            authorId: post.authorId,
            authorName: post.authorName,
            authorEmoji: post.authorEmoji,
            comment: post.comment,
            story: post.story,
            likeCount: likeCount,
            likedBy: likedBy,
            commentCount: post.commentCount,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt)
    }
}
