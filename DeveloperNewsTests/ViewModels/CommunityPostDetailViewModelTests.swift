import XCTest
@testable import DeveloperNews

// Proves CommentService is injected via CommentServicing: a MockCommentServicing
// is supplied and the VM's derived state (visibleComments, error pass-through)
// reflects the mock rather than a hardcoded production service.
@MainActor
final class CommunityPostDetailViewModelTests: XCTestCase {
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

    func testVisibleCommentsFiltersBlockedAuthorsFromInjectedService() async {
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
        XCTAssertEqual(visibleIds, ["c1"])

        // Minimal yield so the AppState-owned persistence task settles before this
        // scope releases the instance, avoiding a teardown race on a pending Task.
        await Task.yield()
    }

    func testCommentErrorMessageReadsFromInjectedService() async {
        let comments = MockCommentServicing()
        comments.errorMessage = "boom"
        let appState = VMFixtures.makeAppState()
        let post = VMFixtures.makePost(id: "post-1")

        let vm = CommunityPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)

        XCTAssertEqual(vm.commentErrorMessage, "boom")

        await Task.yield()
    }

    func testStartListeningForwardsToInjectedService() async {
        let comments = MockCommentServicing()
        let appState = VMFixtures.makeAppState()
        let post = VMFixtures.makePost(id: "post-1")

        let vm = CommunityPostDetailViewModel(
            appState: appState,
            post: post,
            commentService: comments)
        vm.startListening()

        XCTAssertEqual(comments.listeningPostId, "post-1")

        await Task.yield()
    }
}
