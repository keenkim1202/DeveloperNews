import Foundation
import Observation

// Owns the feed subsystem: loading state, reload orchestration (with
// generation-token cancellation), personalization/ranking, and pagination.
// Live inputs that still live in AppState (selected topics, source-category
// toggles, saved snapshots, following items) are read through closures, and
// persistence is delegated back to AppState so writes keep flowing through its
// serial persistence chain. Closures avoid a retain cycle with AppState.
@Observable
@MainActor
final class FeedStore {
    static let pageSize = 30
    static let feedStaleThreshold: TimeInterval = 15 * 60

    private let contentSourceClient: any ContentSourceClient
    private let inputs: Inputs

    var allItems: [ContentItem] = []
    var isLoading = false
    var errorMessage: String?
    var failedSourceNames: [String] = []
    var lastUpdatedAt: Date?
    var visibleItemLimit: Int = pageSize

    @ObservationIgnored
    private var reloadGeneration: Int = 0

    // Reads of AppState-owned inputs and side effects, supplied at init.
    struct Inputs {
        var selectedTopics: @MainActor () -> Set<Topic>
        var focusedTopic: @MainActor () -> Topic?
        var disabledSourceCategories: @MainActor () -> Set<SourceCategory>
        var savedItemSnapshots: @MainActor () -> [URL: ContentItem]
        var followedUserIds: @MainActor () -> Set<String>
        var communityPosts: @MainActor () -> [CommunityPost]
        var isFollowingSourceEnabled: @MainActor () -> Bool
        var persistAllItems: @MainActor ([ContentItem]) -> Void
        var persistLastUpdatedAt: @MainActor (Date?) -> Void
        var showSourcesUnavailableToast: @MainActor () -> Void
    }

    init(
        contentSourceClient: any ContentSourceClient,
        inputs: Inputs,
    ) {
        self.contentSourceClient = contentSourceClient
        self.inputs = inputs
    }

    func setInitialItems(_ items: [ContentItem]) {
        allItems = items
    }

    var hasLoadedContent: Bool {
        !allItems.isEmpty
    }

    // MARK: - Personalization

    var followingItems: [ContentItem] {
        guard inputs.isFollowingSourceEnabled() else { return [] }
        let followedIds = inputs.followedUserIds()
        guard !followedIds.isEmpty else { return [] }

        return inputs.communityPosts()
            .filter { followedIds.contains($0.authorId) }
            .compactMap { post in
                guard let url = URL(string: "devnews://community/\(post.id)") else {
                    return nil
                }
                return ContentItem(
                    id: UUID(uuidString: post.id) ?? UUID(),
                    kind: .article,
                    title: post.title,
                    summary: post.description,
                    sourceName: post.authorName,
                    sourceCategory: .following,
                    authorName: post.authorName,
                    url: url,
                    publishedAt: post.createdAt,
                    topics: post.topics,
                    trendScore: post.likeCount)
            }
    }

    var personalizedItems: [ContentItem] {
        let disabledSourceCategories = inputs.disabledSourceCategories()
        let enabledByCategory = allItems.filter { !disabledSourceCategories.contains($0.sourceCategory) }
        let selectedTopics = inputs.selectedTopics()
        let activeTopics: Set<Topic>
        if let focusedTopic = inputs.focusedTopic(), selectedTopics.contains(focusedTopic) {
            activeTopics = [focusedTopic]
        }
        else {
            activeTopics = selectedTopics
        }

        let filteredItems: [ContentItem]
        if activeTopics.isEmpty {
            filteredItems = enabledByCategory
        }
        else {
            filteredItems = enabledByCategory.filter { item in
                !activeTopics.isDisjoint(with: item.topics)
            }
        }

        let combined = filteredItems + followingItems
        let savedSourceCounts = savedSourceNameCounts()

        return combined.sorted { lhs, rhs in
            let leftScore = personalizedScore(for: lhs, savedSourceCounts: savedSourceCounts)
            let rightScore = personalizedScore(for: rhs, savedSourceCounts: savedSourceCounts)
            if leftScore == rightScore {
                return lhs.publishedAt > rhs.publishedAt
            }
            return leftScore > rightScore
        }
    }

    private func personalizedScore(
        for item: ContentItem,
        savedSourceCounts: [String: Int],
    ) -> Int {
        let saveBonus = min(8, (savedSourceCounts[item.sourceName] ?? 0) * 2)
        return min(100, item.trendScore + saveBonus)
    }

    private func savedSourceNameCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in inputs.savedItemSnapshots().values {
            counts[item.sourceName, default: 0] += 1
        }
        return counts
    }

    var articleItems: [ContentItem] {
        personalizedItems.filter { $0.kind == .article }
    }

    var discussionItems: [ContentItem] {
        personalizedItems.filter { $0.kind == .discussion }
    }

    // MARK: - Pagination

    var pagedPersonalizedItems: [ContentItem] {
        Array(personalizedItems.prefix(visibleItemLimit))
    }

    var pagedArticleItems: [ContentItem] {
        pagedPersonalizedItems.filter { $0.kind == .article }
    }

    var pagedDiscussionItems: [ContentItem] {
        pagedPersonalizedItems.filter { $0.kind == .discussion }
    }

    var hasMorePages: Bool {
        personalizedItems.count > visibleItemLimit
    }

    func loadMore() {
        guard hasMorePages else { return }
        visibleItemLimit += Self.pageSize
    }

    func resetPagination() {
        visibleItemLimit = Self.pageSize
    }

    // MARK: - Orchestration

    func loadIfNeeded() async {
        guard !isLoading else {
            return
        }

        guard hasLoadedContent else {
            await reload()
            return
        }

        await refreshIfStale(maxAge: Self.feedStaleThreshold)
    }

    func refreshIfStale(maxAge: TimeInterval) async {
        guard !isLoading else {
            return
        }

        if let lastUpdatedAt, Date().timeIntervalSince(lastUpdatedAt) < maxAge, hasLoadedContent {
            return
        }

        await reload(notifyOnFailure: false)
    }

    func reload(notifyOnFailure: Bool = true) async {
        let hadLoadedContent = hasLoadedContent
        reloadGeneration += 1
        let generation = reloadGeneration
        isLoading = true
        errorMessage = nil

        let result = await contentSourceClient.fetchItemsWithStatus(selectedTopics: inputs.selectedTopics())

        guard generation == reloadGeneration else {
            return
        }

        let isFullFailure = result.totalSourceCount > 0 &&
            result.failedSourceNames.count == result.totalSourceCount &&
            result.items.isEmpty

        failedSourceNames = result.failedSourceNames

        if isFullFailure, hadLoadedContent {
            if notifyOnFailure {
                inputs.showSourcesUnavailableToast()
            }
            isLoading = false
            return
        }

        allItems = result.items
        lastUpdatedAt = .now
        resetPagination()
        inputs.persistLastUpdatedAt(lastUpdatedAt)
        inputs.persistAllItems(allItems)

        if isFullFailure {
            errorMessage = String(localized: .errorUnableToLoad)
        }

        if notifyOnFailure, !result.failedSourceNames.isEmpty {
            inputs.showSourcesUnavailableToast()
        }

        isLoading = false
    }
}
