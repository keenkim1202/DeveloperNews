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
    ) -> CommunityComment {
        CommunityComment(
            id: id,
            postId: "post-1",
            authorId: authorId,
            authorName: "Author",
            authorEmoji: nil,
            text: "Body",
            createdAt: .now)
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
}
