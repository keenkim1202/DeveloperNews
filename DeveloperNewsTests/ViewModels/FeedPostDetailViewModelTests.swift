import Testing
import Foundation
@testable import DeveloperNews

// Exercises FeedPostDetailViewModel derived state with injected mocks, proving
// CommentService is reachable via CommentServicing and that blocked authors and
// submit guards behave like the community post detail.
@MainActor
@Suite struct FeedPostDetailViewModelTests {
    private func makeComment(
        id: String,
        authorId: String,
        likeCount: Int = 0,
        likedBy: Set<String> = [],
        parentCommentId: String? = nil,
    ) -> CommunityComment {
        CommunityComment(
            id: id,
            postId: "post-1",
            authorId: authorId,
            authorName: "Author",
            authorEmoji: nil,
            text: "Body",
            createdAt: .now,
            likeCount: likeCount,
            likedBy: likedBy,
            parentCommentId: parentCommentId)
    }

    @Test func visibleCommentsFiltersBlockedAuthorsFromInjectedService() async {
        let comments = MockCommentServicing()
        comments.comments = [
            makeComment(id: "c1", authorId: "ok"),
            makeComment(id: "c2", authorId: "blocked")
        ]
        let appState = VMFixtures.makeAppState()
        appState.blockUser("blocked")
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)

        #expect(vm.visibleComments.map(\.id) == ["c1"])

        await Task.yield()
    }

    @Test func commentErrorMessageReadsFromInjectedService() async {
        let comments = MockCommentServicing()
        comments.errorMessage = "boom"
        let appState = VMFixtures.makeAppState()
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)

        #expect(vm.commentErrorMessage == "boom")

        await Task.yield()
    }

    @Test func startListeningForwardsToInjectedService() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState()
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)
        vm.startListening()

        #expect(comments.listeningPostId == "post-1")

        await Task.yield()
    }

    @Test func canSubmitCommentRequiresSignInAndNonEmptyText() async {
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())

        #expect(vm.canSubmitComment(commentText: "  ") == false)
        #expect(vm.canSubmitComment(commentText: "hello") == true)

        await Task.yield()
    }

    @Test func canSubmitCommentFalseWhenSignedOut() async {
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing())
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())

        #expect(vm.canSubmitComment(commentText: "hello") == false)

        await Task.yield()
    }

    @Test func submitReportForwardsReasonToFeedPostService() async {
        let feedPost = MockFeedPostServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            feedPost: feedPost)
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())
        await vm.submitReport(.spam)

        #expect(feedPost.reportedPosts.map(\.postId) == ["post-1"])
        #expect(feedPost.reportedPosts.first?.reason == "spam")

        await Task.yield()
    }

    @Test func reportCommentWhileSignedOutIsNoOp() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing())
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)
        await vm.reportComment(makeComment(id: "c1", authorId: "author"), reason: .spam)

        #expect(comments.reportedComments.isEmpty)

        await Task.yield()
    }

    @Test func reportCommentSignedInDelegatesToServiceWithReason() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)
        await vm.reportComment(makeComment(id: "c1", authorId: "author"), reason: .spam)

        #expect(comments.reportedComments.map(\.commentId) == ["c1"])
        #expect(comments.reportedComments.first?.reporterId == "me")
        #expect(comments.reportedComments.first?.reason == "spam")

        await Task.yield()
    }

    @Test func blockCommentAuthorBlocksTheAuthor() async {
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())
        vm.blockCommentAuthor(makeComment(id: "c1", authorId: "author"))

        #expect(appState.blockedUserIds.contains("author"))

        await Task.yield()
    }

    @Test func toggleCommentLikeWhileSignedOutIsNoOp() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing())
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)
        await vm.toggleCommentLike(makeComment(id: "c1", authorId: "author"))

        #expect(comments.toggledCommentLikes.isEmpty)

        await Task.yield()
    }

    @Test func toggleCommentLikeSignedInDelegatesToService() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))
        let post = VMFixtures.makeFeedPost(id: "post-1")

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)
        await vm.toggleCommentLike(makeComment(id: "c1", authorId: "author"))

        #expect(comments.toggledCommentLikes.map(\.commentId) == ["c1"])
        #expect(comments.toggledCommentLikes.first?.userId == "me")

        await Task.yield()
    }

    @Test func toggleLikeUpdatesLocalLikeState() async {
        let feedPost = MockFeedPostServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            feedPost: feedPost)
        let post = VMFixtures.makeFeedPost(id: "post-1", likeCount: 1)

        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())
        await vm.toggleLike()

        #expect(feedPost.toggledLikes.map(\.postId) == ["post-1"])
        #expect(vm.currentPost.likeCount == 2)
        #expect(vm.isLiked)

        await Task.yield()
    }

    @Test func theAuthorCanDeleteTheirOwnPost() async {
        let feedPost = MockFeedPostServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            feedPost: feedPost)
        let post = VMFixtures.makeFeedPost(id: "post-1", authorId: "me")
        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())

        let deleted = await vm.deletePost()

        #expect(deleted)
        #expect(feedPost.deletedPostIds == ["post-1"])
    }

    // The rules refuse a delete from anyone but the author, so asking is a
    // round trip that can only fail. The menu does not offer it either.
    @Test func aReaderCannotDeleteSomeoneElsesPost() async {
        let feedPost = MockFeedPostServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            feedPost: feedPost)
        let post = VMFixtures.makeFeedPost(id: "post-1", authorId: "someone-else")
        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())

        let deleted = await vm.deletePost()

        #expect(!deleted)
        #expect(feedPost.deletedPostIds.isEmpty)
    }

    // Dismissing the screen on a failed delete would read as success and leave
    // the post in the feed behind it.
    @Test func aFailedDeleteReportsAndKeepsTheScreenOpen() async {
        let feedPost = MockFeedPostServicing()
        feedPost.errorMessage = "no network"
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            feedPost: feedPost)
        let post = VMFixtures.makeFeedPost(id: "post-1", authorId: "me")
        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: MockCommentServicing())

        let deleted = await vm.deletePost()

        #expect(!deleted)
        #expect(appState.toastMessage == "no network")
    }

    // The notification a comment produced points at the comment. Deleting one
    // and leaving the other is a row that opens a post with nothing in it.
    @Test func deletingACommentTakesItsNotificationWithIt() async {
        let comments = MockCommentServicing()
        comments.comments = [makeComment(id: "c1", authorId: "me")]
        let activity = MockActivityServicing()
        activity.activities = [
            Activity(
                id: "commentLike_feedPosts_post-1_c1_someone",
                kind: .commentLike,
                actorId: "someone",
                target: .feedPost("post-1"),
                commentId: "c1",
                story: nil,
                parentCommentId: nil,
                preview: "Body",
                createdAt: .now,
                isRead: false),
        ]
        let appState = VMFixtures.makeAppState(activity: activity)
        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: VMFixtures.makeFeedPost(id: "post-1", authorId: "author-1"),
            commentService: comments)

        await vm.deleteComment(makeComment(id: "c1", authorId: "me"))

        #expect(comments.deletedComments.map(\.postAuthorId) == ["author-1"])
        #expect(activity.deletedActivityIds == [["commentLike_feedPosts_post-1_c1_someone"]])
    }

    // Same for the post: the likes and comments it collected are rows that
    // point at something the reader has just removed.
    @Test func deletingAPostTakesItsNotificationsWithIt() async {
        let activity = MockActivityServicing()
        activity.activities = [
            Activity(
                id: "postLike_feedPosts_post-1_someone",
                kind: .postLike,
                actorId: "someone",
                target: .feedPost("post-1"),
                commentId: nil,
                story: nil,
                parentCommentId: nil,
                preview: "",
                createdAt: .now,
                isRead: false),
            Activity(
                id: "postLike_feedPosts_post-2_someone",
                kind: .postLike,
                actorId: "someone",
                target: .feedPost("post-2"),
                commentId: nil,
                story: nil,
                parentCommentId: nil,
                preview: "",
                createdAt: .now,
                isRead: false),
        ]
        let auth = MockAuthServicing()
        auth.userId = "author-1"
        let appState = VMFixtures.makeAppState(auth: auth, activity: activity)
        let vm = FeedPostDetailViewModel(
            appState: appState,
            post: VMFixtures.makeFeedPost(id: "post-1", authorId: "author-1"),
            commentService: MockCommentServicing())

        #expect(await vm.deletePost())

        #expect(activity.deletedActivityIds == [["postLike_feedPosts_post-1_someone"]])
    }
}
