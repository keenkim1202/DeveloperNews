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
}
