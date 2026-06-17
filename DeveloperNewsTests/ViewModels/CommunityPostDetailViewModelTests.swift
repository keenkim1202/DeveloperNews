import Testing
import Foundation
@testable import DeveloperNews

// Proves CommentService is injected via CommentServicing: a MockCommentServicing
// is supplied and the VM's derived state (visibleComments, error pass-through)
// reflects the mock rather than a hardcoded production service.
@MainActor
@Suite struct CommunityPostDetailViewModelTests {
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
        let post = VMFixtures.makePost(id: "post-1")

        let vm = CommunityPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)

        let visibleIds = vm.visibleComments.map(\.id)
        #expect(visibleIds == ["c1"])

        // Minimal yield so the AppState-owned persistence task settles before this
        // scope releases the instance, avoiding a teardown race on a pending Task.
        await Task.yield()
    }

    @Test func commentErrorMessageReadsFromInjectedService() async {
        let comments = MockCommentServicing()
        comments.errorMessage = "boom"
        let appState = VMFixtures.makeAppState()
        let post = VMFixtures.makePost(id: "post-1")

        let vm = CommunityPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)

        #expect(vm.commentErrorMessage == "boom")

        await Task.yield()
    }

    @Test func startListeningForwardsToInjectedService() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState()
        let post = VMFixtures.makePost(id: "post-1")

        let vm = CommunityPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)
        vm.startListening()

        #expect(comments.listeningPostId == "post-1")

        await Task.yield()
    }
}
