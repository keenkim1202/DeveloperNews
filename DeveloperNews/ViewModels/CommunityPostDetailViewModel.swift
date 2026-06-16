import Foundation
import Observation

@Observable
@MainActor
final class CommunityPostDetailViewModel {
    private let appState: AppState
    private let post: CommunityPost
    private let commentService = CommentService()

    init(
        appState: AppState,
        post: CommunityPost,
    ) {
        self.appState = appState
        self.post = post
    }

    private var community: CommunityService {
        appState.communityService
    }
    var currentUserId: String? {
        appState.authService.userId
    }
    var isAuthor: Bool {
        currentUserId == post.authorId
    }
    var isLiked: Bool {
        guard let uid = currentUserId else { return false }
        return post.likedBy.contains(uid)
    }
    var isFollowingAuthor: Bool {
        appState.profileService.isFollowing(currentPost.authorId)
    }
    var authorEmoji: String? {
        community.authorEmoji(for: currentPost.authorId)
    }

    var currentPost: CommunityPost {
        community.posts.first { $0.id == post.id } ?? post
    }

    var commentErrorMessage: String? {
        commentService.errorMessage
    }

    var visibleComments: [CommunityComment] {
        commentService.comments.filter { !appState.blockedUserIds.contains($0.authorId) }
    }

    func canSubmitComment(commentText: String) -> Bool {
        currentUserId != nil && !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAuthenticatedUser: Bool {
        appState.authService.user != nil
    }

    func startListening() {
        commentService.startListening(postId: post.id)
    }

    func stopListening() {
        commentService.stopListening()
    }

    func markAsRead() {
        appState.markPostAsRead(post.id)
        appState.markURLAsRead("devnews://community/\(post.id)")
    }

    func refreshAlreadyReported() async -> Bool {
        guard let uid = currentUserId else { return false }
        return await community.hasReportedPost(post.id, reporterId: uid)
    }

    func refresh() async {
        await community.refresh()
    }

    func addComment(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let user = appState.authService.user
        else { return }
        await commentService.addComment(
            postId: post.id,
            text: trimmed,
            author: user,
            authorDisplayName: appState.profileService.displayName,
            authorEmoji: appState.profileService.profileEmoji)
    }

    func deleteComment(_ comment: CommunityComment) async {
        await commentService.deleteComment(comment)
    }

    func toggleFollow() async {
        await appState.profileService.toggleFollow(currentPost.authorId)
    }

    func toggleLike() async {
        guard let uid = currentUserId else { return }
        await community.toggleLike(currentPost, userId: uid)
    }

    func deletePost() async {
        await community.deletePost(currentPost)
    }

    func submitReport(_ reason: String) async {
        guard let uid = currentUserId else { return }
        await community.reportPost(currentPost, reporterId: uid, reason: reason)
    }

    func blockAuthor() {
        appState.blockUser(currentPost.authorId)
    }
}
