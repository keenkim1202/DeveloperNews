import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct FeedPostComposerViewModelTests {
    @Test func storyMapsItemFields() {
        let item = VMFixtures.makeItem(
            title: "Swift 6 Concurrency",
            sourceName: "Hacking with Swift",
            urlString: "https://example.com/swift6",
            topics: [.ios, .web])
        let story = FeedPostComposerViewModel.makeStory(from: item)

        #expect(story.url == item.url.absoluteString)
        #expect(story.title == "Swift 6 Concurrency")
        #expect(story.sourceName == "Hacking with Swift")
        #expect(story.sourceCategory == item.sourceCategory)
        #expect(story.topics == [.ios, .web])
        #expect(story.thumbnailURL == nil)
    }

    @Test func storyCarriesThumbnailWhenPresent() {
        let base = VMFixtures.makeItem(urlString: "https://example.com/with-thumb")
        let item = ContentItem(
            id: base.id,
            kind: base.kind,
            title: base.title,
            summary: base.summary,
            sourceName: base.sourceName,
            sourceCategory: base.sourceCategory,
            authorName: base.authorName,
            url: base.url,
            publishedAt: base.publishedAt,
            topics: base.topics,
            trendScore: base.trendScore,
            thumbnailURL: URL(string: "https://example.com/thumb.png"))

        let story = FeedPostComposerViewModel.makeStory(from: item)

        #expect(story.thumbnailURL == "https://example.com/thumb.png")
    }

    @Test func postWhileSignedOutIsNoOp() async {
        let feedPost = MockFeedPostServicing()
        // MockAuthServicing keeps `user` nil since FirebaseAuth.User cannot be
        // constructed in a unit test, so this exercises the signed-out guard.
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(),
            feedPost: feedPost)
        let vm = FeedPostComposerViewModel(
            appState: appState,
            item: VMFixtures.makeItem())

        let didPost = await vm.post(comment: "Great read")

        #expect(didPost == false)
        #expect(feedPost.createdComments.isEmpty)
    }
}
