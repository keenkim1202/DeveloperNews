import Foundation
import Observation

@Observable
@MainActor
final class StoryEngagementViewModel {
    private let appState: AppState
    private let storyURL: String
    private let commentService: any CommentServicing

    /// `commentService` is built here rather than defaulted in the signature,
    /// because it needs the story title, and a default argument cannot read
    /// another argument.
    init(
        appState: AppState,
        storyURL: String,
        storyTitle: String,
        commentService: (any CommentServicing)? = nil,
    ) {
        self.appState = appState
        self.storyURL = storyURL
        self.commentService = commentService ?? CommentService(
            parentCollection: "storyEngagement",
            activityStory: ActivityStory(url: storyURL, title: storyTitle))
    }

    private var storyEngagementService: any StoryEngagementServicing {
        appState.storyEngagementService
    }

    // Engagement comments live under the engagement document, keyed by the same
    // hashed id the engagement record itself uses.
    private var documentId: String {
        StoryEngagement.documentId(for: storyURL)
    }

    private var engagement: StoryEngagement? {
        storyEngagementService.engagement
    }

    var currentUserId: String? {
        appState.authService.userId
    }

    var hasAuthenticatedUser: Bool {
        appState.authService.user != nil
    }

    var isLiked: Bool {
        guard let uid = currentUserId else {
            return false
        }
        return engagement?.likedBy.contains(uid) ?? false
    }

    var likeCount: Int {
        engagement?.likeCount ?? 0
    }

    var commentCount: Int {
        engagement?.commentCount ?? 0
    }

    var viewCount: Int {
        engagement?.viewCount ?? 0
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

    func startListening() async {
        // Avoid creating an empty engagement document just for viewing. The
        // listener tolerates a missing doc and reports zero counts until a real
        // like or comment creates it.
        storyEngagementService.startListening(storyURL: storyURL)
        commentService.startListening(postId: documentId)
    }

    func stopListening() {
        storyEngagementService.stopListening()
        commentService.stopListening()
    }

    func registerView() async {
        // Writes require auth; the service still dedupes locally per day.
        guard currentUserId != nil else {
            return
        }
        await storyEngagementService.registerView(storyURL: storyURL)
        if let message = storyEngagementService.errorMessage {
            appState.presentError(message)
        }
    }

    func toggleLike() async {
        guard let uid = currentUserId else {
            return
        }
        // StoryEngagementService.toggleLike creates-or-updates inside its
        // transaction, so no separate ensureDocument call is required here.
        await storyEngagementService.toggleLike(storyURL: storyURL, userId: uid)
        if let message = storyEngagementService.errorMessage {
            appState.presentError(message)
        }
    }

    func addComment(
        text: String,
        parentCommentId: String? = nil,
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let user = appState.authService.user
        else { return }

        // The parent engagement document must exist before CommentService
        // increments its commentCount, otherwise the update fails.
        await storyEngagementService.ensureDocument(storyURL: storyURL)
        await commentService.addComment(
            postId: documentId,
            // A story is nobody's post. A reply still notifies the person it
            // answers; a top-level comment notifies no one.
            postAuthorId: "",
            text: trimmed,
            author: user,
            authorDisplayName: appState.profileService.displayName,
            authorEmoji: appState.profileService.profileEmoji,
            parentCommentId: parentCommentId)
    }

    func deleteComment(_ comment: CommunityComment) async {
        // A story is nobody's post, the same as when the comment was written.
        await commentService.deleteComment(comment, postAuthorId: "")
        await appState.purgeActivities(aboutComment: comment.id)
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
}
