import Foundation
import Testing
@testable import DeveloperNews

// The community post route used to answer only from the loaded window, so an
// activity row pointing at an older post reported it deleted. These pin the two
// lookups apart: `post(id:)` sees the window, `fetchPost(id:)` sees the store.
@MainActor
@Suite struct CommunityPostResolutionTests {
    private func makeService() -> MockCommunityServicing {
        let service = MockCommunityServicing()
        service.posts = [VMFixtures.makePost(id: "loaded")]
        service.unloadedPosts = [VMFixtures.makePost(id: "older")]
        return service
    }

    @Test func theInMemoryLookupOnlySeesTheLoadedWindow() {
        let service = makeService()

        #expect(service.post(id: "loaded") != nil)
        #expect(service.post(id: "older") == nil)
    }

    @Test func fetchingByIdReachesAPostOutsideTheLoadedWindow() async throws {
        let service = makeService()

        let post = try await service.fetchPost(id: "older")

        #expect(post?.id == "older")
    }

    @Test func fetchingByIdReturnsNilForAPostThatIsGone() async throws {
        let service = makeService()

        let post = try await service.fetchPost(id: "deleted")

        #expect(post == nil)
    }

    // A read that fails has to throw rather than report a deletion, or a
    // dropped network tells the user their post is gone.
    @Test func aFailedReadThrowsInsteadOfReportingADeletion() async {
        struct Failure: Error {}
        let service = makeService()
        service.fetchPostError = Failure()

        await #expect(throws: Failure.self) {
            try await service.fetchPost(id: "older")
        }
    }
}
