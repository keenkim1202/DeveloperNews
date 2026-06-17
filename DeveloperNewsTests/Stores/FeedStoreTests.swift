import Testing
import Foundation
@testable import DeveloperNews

// Constructs FeedStore directly with a fixed content source and test input
// closures, then exercises reload, personalization/ranking, and pagination.
@MainActor
@Suite struct FeedStoreTests {
    private struct InputState {
        var selectedTopics: Set<Topic> = []
        var focusedTopic: Topic?
        var disabledSourceCategories: Set<SourceCategory> = []
        var savedItemSnapshots: [URL: ContentItem] = [:]
    }

    private func makeStore(
        items: [ContentItem],
        state: InputState = InputState(),
        delay: Duration = .zero,
        failedSourceNames: [String] = [],
        totalSourceCount: Int = 1,
    ) -> FeedStore {
        let client = FixedContentSourceClient(
            items: items,
            failedSourceNames: failedSourceNames,
            totalSourceCount: totalSourceCount,
            delay: delay)
        return FeedStore(
            contentSourceClient: client,
            inputs: FeedStore.Inputs(
                selectedTopics: { state.selectedTopics },
                focusedTopic: { state.focusedTopic },
                disabledSourceCategories: { state.disabledSourceCategories },
                savedItemSnapshots: { state.savedItemSnapshots },
                followedUserIds: { [] },
                communityPosts: { [] },
                isFollowingSourceEnabled: { false },
                persistAllItems: { _ in },
                persistLastUpdatedAt: { _ in },
                showSourcesUnavailableToast: {}))
    }

    @Test func reloadPopulatesAllItems() async {
        let items = [
            StoreTestSupport.makeItem(urlString: "https://example.com/a"),
            StoreTestSupport.makeItem(urlString: "https://example.com/b")
        ]
        let store = makeStore(items: items)

        await store.reload()

        #expect(store.allItems.count == 2)
        #expect(!store.isLoading)
        #expect(store.lastUpdatedAt != nil)
        #expect(store.hasLoadedContent)
    }

    @Test func personalizedItemsRankedByScoreThenRecency() async {
        let high = StoreTestSupport.makeItem(
            urlString: "https://example.com/high",
            trendScore: 80,
            publishedAt: Date(timeIntervalSince1970: 100))
        let lowNew = StoreTestSupport.makeItem(
            urlString: "https://example.com/low-new",
            trendScore: 10,
            publishedAt: Date(timeIntervalSince1970: 9000))
        let lowOld = StoreTestSupport.makeItem(
            urlString: "https://example.com/low-old",
            trendScore: 10,
            publishedAt: Date(timeIntervalSince1970: 1000))
        let store = makeStore(items: [lowOld, lowNew, high])

        await store.reload()

        // Highest score first; ties broken by newer publishedAt.
        #expect(store.personalizedItems.map(\.url) == [high.url, lowNew.url, lowOld.url])
    }

    @Test func savedSourceBonusRaisesRanking() async {
        // Two items with equal base score; the one whose source is heavily saved
        // gets a save bonus and should rank ahead.
        let plain = StoreTestSupport.makeItem(
            urlString: "https://example.com/plain",
            sourceName: "Plain",
            trendScore: 50,
            publishedAt: Date(timeIntervalSince1970: 5000))
        let boosted = StoreTestSupport.makeItem(
            urlString: "https://example.com/boosted",
            sourceName: "Favorite",
            trendScore: 50,
            publishedAt: Date(timeIntervalSince1970: 1000))

        var state = InputState()
        let saved1 = StoreTestSupport.makeItem(urlString: "https://example.com/s1", sourceName: "Favorite")
        let saved2 = StoreTestSupport.makeItem(urlString: "https://example.com/s2", sourceName: "Favorite")
        state.savedItemSnapshots = [saved1.url: saved1, saved2.url: saved2]

        let store = makeStore(items: [plain, boosted], state: state)

        await store.reload()

        #expect(store.personalizedItems.first?.url == boosted.url)
    }

    @Test func disabledSourceCategoryFiltersItems() async {
        let article = StoreTestSupport.makeItem(
            urlString: "https://example.com/article",
            sourceCategory: .article)
        let reddit = StoreTestSupport.makeItem(
            urlString: "https://example.com/reddit",
            sourceCategory: .reddit)

        var state = InputState()
        state.disabledSourceCategories = [.reddit]
        let store = makeStore(items: [article, reddit], state: state)

        await store.reload()

        #expect(store.personalizedItems.map(\.url) == [article.url])
    }

    @Test func selectedTopicFiltersItems() async {
        let iosItem = StoreTestSupport.makeItem(urlString: "https://example.com/ios", topics: [.ios])
        let aiItem = StoreTestSupport.makeItem(urlString: "https://example.com/ai", topics: [.ai])

        var state = InputState()
        state.selectedTopics = [.ios]
        let store = makeStore(items: [iosItem, aiItem], state: state)

        await store.reload()

        #expect(store.personalizedItems.map(\.url) == [iosItem.url])
    }

    @Test func paginationLimitsAndLoadMore() async {
        let items = (0..<(FeedStore.pageSize + 10)).map { index in
            StoreTestSupport.makeItem(
                urlString: "https://example.com/item-\(index)",
                trendScore: index)
        }
        let store = makeStore(items: items)

        await store.reload()

        #expect(store.pagedPersonalizedItems.count == FeedStore.pageSize)
        #expect(store.hasMorePages)

        store.loadMore()

        #expect(store.pagedPersonalizedItems.count == items.count)
        #expect(!store.hasMorePages)
    }

    @Test func reloadResetsPagination() async {
        let items = (0..<(FeedStore.pageSize + 5)).map { index in
            StoreTestSupport.makeItem(urlString: "https://example.com/item-\(index)")
        }
        let store = makeStore(items: items)

        await store.reload()
        store.loadMore()
        #expect(store.visibleItemLimit > FeedStore.pageSize)

        await store.reload()
        #expect(store.visibleItemLimit == FeedStore.pageSize)
    }

    @Test func overlappingReloadsApplyResultExactlyOnce() async {
        // Two reloads overlap on the same store. The generation guard must cause
        // the stale (first) reload to bail without re-applying its result, so a
        // persist side effect fires once per winning reload, not once per call.
        let items = [StoreTestSupport.makeItem(urlString: "https://example.com/x")]
        let client = FixedContentSourceClient(items: items, delay: .milliseconds(150))

        var persistCount = 0
        let store = FeedStore(
            contentSourceClient: client,
            inputs: FeedStore.Inputs(
                selectedTopics: { [] },
                focusedTopic: { nil },
                disabledSourceCategories: { [] },
                savedItemSnapshots: { [:] },
                followedUserIds: { [] },
                communityPosts: { [] },
                isFollowingSourceEnabled: { false },
                persistAllItems: { _ in persistCount += 1 },
                persistLastUpdatedAt: { _ in },
                showSourcesUnavailableToast: {}))

        // Fire two overlapping reloads. The first is superseded by the second's
        // generation bump, so only the second reaches the persist call.
        async let first: Void = store.reload()
        async let second: Void = store.reload()
        _ = await (first, second)

        #expect(store.allItems.map(\.url) == items.map(\.url))
        #expect(!store.isLoading)
        // Stale reload bailed at the generation guard; only one persist happened.
        #expect(persistCount == 1)
    }
}
