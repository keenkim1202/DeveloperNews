import Foundation
import Observation

@Observable
@MainActor
final class FeedPostDetailViewModel {
    private let appState: AppState
    private let commentService: any CommentServicing

    // Snapshot of the post as it was read when the detail view appeared. Like
    // state is managed locally since the feed services do not expose a live
    // `posts` collection to read back from.
    private(set) var currentPost: FeedPost

    init(
        appState: AppState,
        post: FeedPost,
        commentService: any CommentServicing = CommentService(parentCollection: "feedPosts"),
    ) {
        self.appState = appState
        self.currentPost = post
        self.commentService = commentService
    }

    private var feedPostService: any FeedPostServicing {
        appState.feedPostService
    }
    var currentUserId: String? {
        appState.authService.userId
    }
    var isAuthor: Bool {
        currentUserId == currentPost.authorId
    }
    var isLiked: Bool {
        guard let uid = currentUserId else {
            return false
        }
        return currentPost.likedBy.contains(uid)
    }

    var commentErrorMessage: String? {
        commentService.errorMessage
    }

    var visibleComments: [CommunityComment] {
        commentService.comments.filter { !appState.blockedUserIds.contains($0.authorId) }
    }

    var commentThreads: [CommentThread] {
        CommentThread.build(from: visibleComments)
    }

    func canSubmitComment(commentText: String) -> Bool {
        currentUserId != nil && !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAuthenticatedUser: Bool {
        appState.authService.user != nil
    }

    func startListening() {
        commentService.startListening(postId: currentPost.id)
    }

    func stopListening() {
        commentService.stopListening()
    }

    func addComment(
        text: String,
        parentCommentId: String? = nil,
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let user = appState.authService.user
        else { return }
        await commentService.addComment(
            postId: currentPost.id,
            postAuthorId: currentPost.authorId,
            text: trimmed,
            author: user,
            authorDisplayName: appState.profileService.displayName,
            authorEmoji: appState.profileService.profileEmoji,
            parentCommentId: parentCommentId)
    }

    func deleteComment(_ comment: CommunityComment) async {
        await commentService.deleteComment(comment)
    }

    func reportComment(
        _ comment: CommunityComment,
        reason: ReportReason,
    ) async {
        guard let uid = currentUserId else {
            return
        }
        await commentService.reportComment(comment, reporterId: uid, reason: reason.storageValue)
        if let message = commentService.errorMessage {
            appState.presentError(message)
        }
    }

    func blockCommentAuthor(_ comment: CommunityComment) {
        appState.blockUser(comment.authorId)
    }

    func toggleCommentLike(_ comment: CommunityComment) async {
        guard let uid = currentUserId else {
            return
        }
        await commentService.toggleCommentLike(comment, userId: uid)
        if let message = commentService.errorMessage {
            appState.presentError(message)
        }
    }

    func toggleLike() async {
        guard let uid = currentUserId else {
            return
        }
        await feedPostService.toggleLike(currentPost, userId: uid)
        if let message = feedPostService.errorMessage {
            appState.presentError(message)
            return
        }
        currentPost = Self.applyLikeToggle(currentPost, userId: uid)
    }

    func updateComment(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let uid = currentUserId,
              isAuthor
        else { return }
        await feedPostService.updatePost(currentPost, comment: trimmed, editorId: uid)
        if let message = feedPostService.errorMessage {
            appState.presentError(message)
            return
        }
        currentPost = Self.applyComment(currentPost, comment: trimmed)
    }

    func submitReport(_ reason: ReportReason) async {
        guard let uid = currentUserId else {
            return
        }
        await feedPostService.reportPost(currentPost, reporterId: uid, reason: reason.storageValue)
        if let message = feedPostService.errorMessage {
            appState.presentError(message)
        }
    }

    func blockAuthor() {
        appState.blockUser(currentPost.authorId)
    }

    private static func applyComment(
        _ post: FeedPost,
        comment: String,
    ) -> FeedPost {
        FeedPost(
            id: post.id,
            authorId: post.authorId,
            authorName: post.authorName,
            authorEmoji: post.authorEmoji,
            comment: comment,
            story: post.story,
            likeCount: post.likeCount,
            likedBy: post.likedBy,
            commentCount: post.commentCount,
            createdAt: post.createdAt,
            updatedAt: Date())
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
