import Foundation
import Testing
@testable import DeveloperNews

@MainActor
@Suite struct ActivityDocumentTests {
    private func makeDraft(
        kind: ActivityKind,
        target: ActivityTarget? = nil,
        commentId: String? = nil,
    ) -> ActivityDraft {
        ActivityDraft(
            kind: kind,
            recipientId: "recipient",
            actorId: "actor",
            target: target,
            commentId: commentId,
            preview: "preview")
    }

    @Test func stableIdIsUniquePerToggleablePair() {
        let follow = ActivityDocument.stableId(for: makeDraft(kind: .follow))
        let likeOnFeedPost = ActivityDocument.stableId(
            for: makeDraft(kind: .postLike, target: .feedPost("p1")))
        let likeOnCommunityPost = ActivityDocument.stableId(
            for: makeDraft(kind: .postLike, target: .communityPost("p1")))
        let commentLike = ActivityDocument.stableId(
            for: makeDraft(kind: .commentLike, target: .feedPost("p1"), commentId: "c1"))

        #expect(follow == "follow_actor")
        #expect(likeOnFeedPost == "postLike_feedPosts_p1_actor")
        // Same post id in a different collection must not collide.
        #expect(likeOnCommunityPost == "postLike_posts_p1_actor")
        #expect(commentLike == "commentLike_feedPosts_p1_c1_actor")
    }

    // The create rule rebuilds this id from the document's own fields and
    // rejects a write that lands anywhere else, which is what keeps one action
    // to one inbox row. Changing the format here without changing
    // `expectedActivityId` in firestore.rules silently stops every write.
    @Test func stableIdMatchesTheFormatTheSecurityRulesRebuild() {
        let comment = ActivityDocument.stableId(
            for: makeDraft(kind: .postComment, target: .feedPost("p1"), commentId: "c1"))

        #expect(comment == "postComment_feedPosts_p1_c1_actor")
    }

    @Test func stableIdIsStableAcrossRepeatedToggles() {
        let draft = makeDraft(kind: .postLike, target: .feedPost("p1"))

        #expect(ActivityDocument.stableId(for: draft) == ActivityDocument.stableId(for: draft))
    }

    @Test func targetRoundTripsThroughItsCollectionName() {
        let targets: [ActivityTarget] = [.feedPost("p1"), .communityPost("p2")]

        for target in targets {
            let restored = ActivityTarget(
                collectionName: target.collectionName,
                postId: target.postId)
            #expect(restored == target)
        }
    }

    @Test func storyEngagementHasNoTarget() {
        #expect(ActivityTarget(collectionName: "storyEngagement", postId: "hash") == nil)
    }

    private func makeComment(
        id: String = "c1",
        authorId: String = "comment-author",
    ) -> CommunityComment {
        CommunityComment(
            id: id,
            postId: "p1",
            authorId: authorId,
            authorName: "Author",
            authorEmoji: nil,
            text: "Parent comment",
            createdAt: .now,
            likeCount: 0,
            likedBy: [],
            parentCommentId: nil)
    }

    @Test func topLevelCommentNotifiesThePostAuthor() {
        let draft = CommentService.commentActivityDraft(
            parentCollection: "feedPosts",
            postId: "p1",
            postAuthorId: "post-author",
            parentComment: nil,
            actorId: "actor",
            commentId: "new",
            text: "Nice")

        #expect(draft?.kind == .postComment)
        #expect(draft?.recipientId == "post-author")
        #expect(draft?.target == .feedPost("p1"))
    }

    @Test func replyNotifiesTheParentCommentAuthor() {
        let draft = CommentService.commentActivityDraft(
            parentCollection: "posts",
            postId: "p1",
            postAuthorId: "post-author",
            parentComment: makeComment(authorId: "parent-author"),
            actorId: "actor",
            commentId: "new",
            text: "Agreed")

        #expect(draft?.kind == .commentReply)
        #expect(draft?.recipientId == "parent-author")
        #expect(draft?.target == .communityPost("p1"))
    }

    // A reply whose parent has fallen outside the comment listener window has
    // nobody to name, so it degrades to a comment on the post.
    @Test func replyWithAnUnresolvedParentFallsBackToThePostAuthor() {
        let draft = CommentService.commentActivityDraft(
            parentCollection: "feedPosts",
            postId: "p1",
            postAuthorId: "post-author",
            parentComment: nil,
            actorId: "actor",
            commentId: "new",
            text: "Agreed")

        #expect(draft?.kind == .postComment)
        #expect(draft?.recipientId == "post-author")
    }

    @Test func storyCommentsProduceNoActivity() {
        let draft = CommentService.commentActivityDraft(
            parentCollection: "storyEngagement",
            postId: "hash",
            postAuthorId: "",
            parentComment: nil,
            actorId: "actor",
            commentId: "new",
            text: "Nice")

        #expect(draft == nil)
    }
}
