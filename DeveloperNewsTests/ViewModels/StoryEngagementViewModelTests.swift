import Testing
import Foundation
@testable import DeveloperNews

// Exercises StoryEngagementViewModel derived state with injected mocks, proving
// the engagement service is reachable, like toggling is gated on sign-in, and
// blocked authors are filtered like the feed post detail.
@MainActor
@Suite struct StoryEngagementViewModelTests {
    private let storyURL = "https://example.com/story"

    private func makeComment(
        id: String,
        authorId: String,
        likeCount: Int = 0,
        likedBy: Set<String> = [],
        parentCommentId: String? = nil,
    ) -> CommunityComment {
        CommunityComment(
            id: id,
            postId: StoryEngagement.documentId(for: storyURL),
            authorId: authorId,
            authorName: "Author",
            authorEmoji: nil,
            text: "Body",
            createdAt: .now,
            likeCount: likeCount,
            likedBy: likedBy,
            parentCommentId: parentCommentId)
    }

    private func makeEngagement(
        likeCount: Int,
        likedBy: Set<String>,
        commentCount: Int = 0,
        viewCount: Int = 0,
    ) -> StoryEngagement {
        StoryEngagement(
            id: StoryEngagement.documentId(for: storyURL),
            storyURL: storyURL,
            likeCount: likeCount,
            likedBy: likedBy,
            commentCount: commentCount,
            viewCount: viewCount)
    }

    @Test func toggleLikeWhileSignedOutIsNoOp() async {
        let storyEngagement = MockStoryEngagementServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())
        await vm.toggleLike()

        #expect(storyEngagement.toggledLikes.isEmpty)
        #expect(storyEngagement.ensuredURLs.isEmpty)
    }

    @Test func toggleLikeSignedInCallsServiceWithoutEnsuringDocument() async {
        let storyEngagement = MockStoryEngagementServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())
        await vm.toggleLike()

        #expect(storyEngagement.ensuredURLs.isEmpty)
        #expect(storyEngagement.toggledLikes.map(\.storyURL) == [storyURL])
        #expect(storyEngagement.toggledLikes.first?.userId == "me")
    }

    @Test func isLikedAndLikeCountReflectSeededEngagement() async {
        let storyEngagement = MockStoryEngagementServicing()
        storyEngagement.engagement = makeEngagement(likeCount: 3, likedBy: ["me", "other"])
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())

        #expect(vm.isLiked)
        #expect(vm.likeCount == 3)
    }

    @Test func isLikedFalseWhenUserNotInLikedBy() async {
        let storyEngagement = MockStoryEngagementServicing()
        storyEngagement.engagement = makeEngagement(likeCount: 1, likedBy: ["other"])
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())

        #expect(vm.isLiked == false)
        #expect(vm.likeCount == 1)
    }

    @Test func viewCountReflectsSeededEngagement() async {
        let storyEngagement = MockStoryEngagementServicing()
        storyEngagement.engagement = makeEngagement(likeCount: 0, likedBy: [], viewCount: 42)
        let appState = VMFixtures.makeAppState(storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())

        #expect(vm.viewCount == 42)
    }

    @Test func registerViewWhileSignedOutIsNoOp() async {
        let storyEngagement = MockStoryEngagementServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())
        await vm.registerView()

        #expect(storyEngagement.registeredViews.isEmpty)
    }

    @Test func registerViewSignedInRecordsView() async {
        let storyEngagement = MockStoryEngagementServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())
        await vm.registerView()

        #expect(storyEngagement.registeredViews == [storyURL])
    }

    @Test func commentCountReflectsSeededEngagement() async {
        let storyEngagement = MockStoryEngagementServicing()
        storyEngagement.engagement = makeEngagement(likeCount: 0, likedBy: [], commentCount: 5)
        let appState = VMFixtures.makeAppState(storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())

        #expect(vm.commentCount == 5)
    }

    @Test func visibleCommentsFiltersBlockedAuthors() async {
        let comments = MockCommentServicing()
        comments.comments = [
            makeComment(id: "c1", authorId: "ok"),
            makeComment(id: "c2", authorId: "blocked")
        ]
        let appState = VMFixtures.makeAppState()
        appState.blockUser("blocked")

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: comments)

        #expect(vm.visibleComments.map(\.id) == ["c1"])
    }

    @Test func startListeningStartsListenersWithoutEnsuringDocument() async {
        let storyEngagement = MockStoryEngagementServicing()
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: comments)
        await vm.startListening()

        #expect(storyEngagement.ensuredURLs.isEmpty)
        #expect(storyEngagement.listeningStoryURL == storyURL)
        #expect(comments.listeningPostId == StoryEngagement.documentId(for: storyURL))
    }

    @Test func addCommentWhileSignedOutDoesNotEnsureDocument() async {
        let storyEngagement = MockStoryEngagementServicing()
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: comments)
        await vm.addComment(text: "hello")

        #expect(storyEngagement.ensuredURLs.isEmpty)
    }

    @Test func canSubmitCommentRequiresSignInAndNonEmptyText() async {
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())

        #expect(vm.canSubmitComment(commentText: "  ") == false)
        #expect(vm.canSubmitComment(commentText: "hello") == true)
    }

    @Test func reportCommentWhileSignedOutIsNoOp() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing())

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: comments)
        await vm.reportComment(makeComment(id: "c1", authorId: "author"), reason: .spam)

        #expect(comments.reportedComments.isEmpty)
    }

    @Test func reportCommentSignedInDelegatesToServiceWithReason() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: comments)
        await vm.reportComment(makeComment(id: "c1", authorId: "author"), reason: .inappropriate)

        #expect(comments.reportedComments.map(\.commentId) == ["c1"])
        #expect(comments.reportedComments.first?.reporterId == "me")
        #expect(comments.reportedComments.first?.reason == "inappropriate")
    }

    @Test func blockCommentAuthorBlocksTheAuthor() async {
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: MockCommentServicing())
        vm.blockCommentAuthor(makeComment(id: "c1", authorId: "author"))

        #expect(appState.blockedUserIds.contains("author"))
    }

    @Test func toggleCommentLikeWhileSignedOutIsNoOp() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing())

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: comments)
        await vm.toggleCommentLike(makeComment(id: "c1", authorId: "author"))

        #expect(comments.toggledCommentLikes.isEmpty)
    }

    @Test func toggleCommentLikeSignedInDelegatesToService() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            storyTitle: "Story",
            commentService: comments)
        await vm.toggleCommentLike(makeComment(id: "c1", authorId: "author"))

        #expect(comments.toggledCommentLikes.map(\.commentId) == ["c1"])
        #expect(comments.toggledCommentLikes.first?.userId == "me")
    }
}
