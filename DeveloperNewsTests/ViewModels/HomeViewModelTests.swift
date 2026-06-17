import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct HomeViewModelTests {
    // Seeds the feed via a stub content source + reload so feed-derived state
    // (personalizedItems, paged items) is populated.
    private func makeSeededAppState(_ items: [ContentItem]) async -> AppState {
        let appState = VMFixtures.makeAppState(
            contentSourceClient: StubContentSourceClient(items: items))
        // Empty selectedTopics makes personalizedItems return every seeded item.
        await appState.reload()
        return appState
    }

    @Test func shouldShowTopStoryFalseWhenFeedEmpty() async {
        let appState = await makeSeededAppState([])
        let vm = HomeViewModel(appState: appState)

        #expect(!vm.shouldShowTopStory)
        #expect(vm.topItem == nil)
    }

    @Test func topItemIsFirstPersonalizedWhenNoSearch() async {
        let high = VMFixtures.makeItem(title: "Top", trendScore: 100)
        let low = VMFixtures.makeItem(title: "Low", trendScore: 1)
        let appState = await makeSeededAppState([low, high])
        let vm = HomeViewModel(appState: appState)

        #expect(vm.shouldShowTopStory)
        #expect(vm.topItem?.title == "Top")
    }

    @Test func topItemSuppressedDuringSearch() async {
        let appState = await makeSeededAppState([
            VMFixtures.makeItem(title: "Top", trendScore: 100)
        ])
        let vm = HomeViewModel(appState: appState)

        vm.searchQuery = "Top"
        #expect(vm.topItem == nil)
    }

    @Test func articlesExcludingTopStoryDropsTheTopItem() async {
        let top = VMFixtures.makeItem(title: "Top", trendScore: 100)
        let other = VMFixtures.makeItem(title: "Other", trendScore: 50)
        let appState = await makeSeededAppState([top, other])
        let vm = HomeViewModel(appState: appState)

        #expect(vm.topItem?.title == "Top")
        let remaining = vm.articlesExcludingTopStory.map(\.title)
        #expect(!remaining.contains("Top"))
        #expect(remaining.contains("Other"))
    }

    @Test func searchFiltersArticles() async {
        let appState = await makeSeededAppState([
            VMFixtures.makeItem(title: "SwiftUI", trendScore: 10),
            VMFixtures.makeItem(title: "Kotlin", trendScore: 9)
        ])
        let vm = HomeViewModel(appState: appState)

        vm.searchQuery = "swiftui"
        let titles = vm.filteredArticleItems.map(\.title)
        #expect(titles == ["SwiftUI"])
    }

    @Test func loadEngagementsKeysByURLAndMergesAcrossCalls() async {
        let shown = VMFixtures.makeItem(title: "Shown", trendScore: 50)
        let unknown = VMFixtures.makeItem(title: "Unknown", trendScore: 1)

        let engagement = StoryEngagement(
            id: StoryEngagement.documentId(for: shown.url.absoluteString),
            storyURL: shown.url.absoluteString,
            likeCount: 3,
            likedBy: ["u1"],
            commentCount: 2)
        let mock = MockStoryEngagementServicing()
        mock.fetchedEngagements = [shown.url.absoluteString: engagement]

        let appState = VMFixtures.makeAppState(
            storyEngagement: mock,
            contentSourceClient: StubContentSourceClient(items: [shown]))
        await appState.reload()
        let vm = HomeViewModel(appState: appState)

        await vm.loadEngagements()
        #expect(vm.engagement(for: shown) == engagement)
        #expect(vm.engagement(for: unknown) == nil)

        // A second fetch with a different key must not drop the first entry.
        let other = VMFixtures.makeItem(title: "Other", trendScore: 2)
        let otherEngagement = StoryEngagement(
            id: StoryEngagement.documentId(for: other.url.absoluteString),
            storyURL: other.url.absoluteString,
            likeCount: 1,
            likedBy: [],
            commentCount: 0)
        mock.fetchedEngagements = [other.url.absoluteString: otherEngagement]

        await vm.loadEngagements()
        #expect(vm.engagement(for: shown) == engagement)
        #expect(vm.engagement(for: other) == otherEngagement)
    }

    @Test func shouldShowTopStoryFalseWhenDismissedRecently() async {
        let appState = await makeSeededAppState([
            VMFixtures.makeItem(title: "Top", trendScore: 100)
        ])
        appState.topStoryDismissedAt = .now
        let vm = HomeViewModel(appState: appState)

        #expect(appState.isTopStoryHidden)
        #expect(!vm.shouldShowTopStory)
    }
}
