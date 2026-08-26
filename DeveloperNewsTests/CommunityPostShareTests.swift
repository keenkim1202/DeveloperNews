import Foundation
import Testing
@testable import DeveloperNews

// A post has no address of its own — the app publishes nothing to the web — so
// what a text-only post can hand a recipient is its own text.
@MainActor
@Suite struct CommunityPostShareTests {
    @Test func shareTextCarriesTitleAndBody() {
        let post = VMFixtures.makePost(title: "Ship it", description: "Here is why")

        #expect(post.shareText == "Ship it\n\nHere is why")
    }

    @Test func aPostWithNoBodySharesItsTitleAlone() {
        let post = VMFixtures.makePost(title: "Ship it", description: "")

        #expect(post.shareText == "Ship it")
    }
}
