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
    ) -> CommunityComment {
        CommunityComment(
            id: id,
            postId: StoryEngagement.documentId(for: storyURL),
            authorId: authorId,
            authorName: "Author",
            authorEmoji: nil,
            text: "Body",
            createdAt: .now)
    }

    private func makeEngagement(
        likeCount: Int,
        likedBy: Set<String>,
        commentCount: Int = 0,
    ) -> StoryEngagement {
        StoryEngagement(
            id: StoryEngagement.documentId(for: storyURL),
            storyURL: storyURL,
            likeCount: likeCount,
            likedBy: likedBy,
            commentCount: commentCount)
    }

    @Test func toggleLikeWhileSignedOutIsNoOp() async {
        let storyEngagement = MockStoryEngagementServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            commentService: MockCommentServicing())
        await vm.toggleLike()

        #expect(storyEngagement.toggledLikes.isEmpty)
        #expect(storyEngagement.ensuredURLs.isEmpty)
    }

    @Test func toggleLikeSignedInCallsServiceAndEnsuresDocument() async {
        let storyEngagement = MockStoryEngagementServicing()
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            commentService: MockCommentServicing())
        await vm.toggleLike()

        #expect(storyEngagement.ensuredURLs == [storyURL])
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
            commentService: MockCommentServicing())

        #expect(vm.isLiked == false)
        #expect(vm.likeCount == 1)
    }

    @Test func commentCountReflectsSeededEngagement() async {
        let storyEngagement = MockStoryEngagementServicing()
        storyEngagement.engagement = makeEngagement(likeCount: 0, likedBy: [], commentCount: 5)
        let appState = VMFixtures.makeAppState(storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
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
            commentService: comments)

        #expect(vm.visibleComments.map(\.id) == ["c1"])
    }

    @Test func startListeningEnsuresDocumentThenStartsListeners() async {
        let storyEngagement = MockStoryEngagementServicing()
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState(storyEngagement: storyEngagement)

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            commentService: comments)
        await vm.startListening()

        #expect(storyEngagement.ensuredURLs == [storyURL])
        #expect(storyEngagement.listeningStoryURL == storyURL)
        #expect(comments.listeningPostId == StoryEngagement.documentId(for: storyURL))
    }

    @Test func canSubmitCommentRequiresSignInAndNonEmptyText() async {
        let appState = VMFixtures.makeAppState(auth: MockAuthServicing(userId: "me"))

        let vm = StoryEngagementViewModel(
            appState: appState,
            storyURL: storyURL,
            commentService: MockCommentServicing())

        #expect(vm.canSubmitComment(commentText: "  ") == false)
        #expect(vm.canSubmitComment(commentText: "hello") == true)
    }
}
