import Testing
import Foundation
@testable import DeveloperNews

// Verifies CommentThread.build groups a flat comment list into single-level
// threads: top-level order preserved, replies nested and time-sorted, orphans
// dropped.
@MainActor
@Suite struct CommentThreadTests {
    private func makeComment(
        id: String,
        createdAt: Date,
        parentCommentId: String? = nil,
    ) -> CommunityComment {
        CommunityComment(
            id: id,
            postId: "post-1",
            authorId: "author",
            authorName: "Author",
            authorEmoji: nil,
            text: "Body",
            createdAt: createdAt,
            likeCount: 0,
            likedBy: [],
            parentCommentId: parentCommentId)
    }

    @Test func preservesTopLevelOrder() {
        let base = Date()
        let comments = [
            makeComment(id: "a", createdAt: base),
            makeComment(id: "b", createdAt: base.addingTimeInterval(1)),
            makeComment(id: "c", createdAt: base.addingTimeInterval(2))
        ]

        let threads = CommentThread.build(from: comments)

        #expect(threads.map(\.id) == ["a", "b", "c"])
        #expect(threads.allSatisfy { $0.replies.isEmpty })
    }

    @Test func groupsRepliesUnderParentSortedByCreatedAt() {
        let base = Date()
        let comments = [
            makeComment(id: "parent", createdAt: base),
            makeComment(id: "r2", createdAt: base.addingTimeInterval(2), parentCommentId: "parent"),
            makeComment(id: "r1", createdAt: base.addingTimeInterval(1), parentCommentId: "parent")
        ]

        let threads = CommentThread.build(from: comments)

        #expect(threads.count == 1)
        #expect(threads.first?.id == "parent")
        #expect(threads.first?.replies.map(\.id) == ["r1", "r2"])
    }

    @Test func dropsOrphanReplies() {
        let base = Date()
        let comments = [
            makeComment(id: "parent", createdAt: base),
            makeComment(id: "reply", createdAt: base.addingTimeInterval(1), parentCommentId: "parent"),
            makeComment(id: "orphan", createdAt: base.addingTimeInterval(2), parentCommentId: "missing")
        ]

        let threads = CommentThread.build(from: comments)

        #expect(threads.map(\.id) == ["parent"])
        #expect(threads.first?.replies.map(\.id) == ["reply"])
    }

    @Test func emptyInputProducesNoThreads() {
        #expect(CommentThread.build(from: []).isEmpty)
    }
}
