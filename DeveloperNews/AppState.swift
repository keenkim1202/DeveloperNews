import Foundation
import Observation

@Observable
final class AppState {
    static let maxSelectedTopics = 5
    static let pageSize = 30

    private enum StorageKey {
        static let selectedTopics = "selectedTopics"
        static let savedItemIDs = "savedItemIDs"
        static let savedItemTimestamps = "savedItemTimestamps"
        static let savedItemSnapshots = "savedItemSnapshots"
        static let savedSortOrder = "savedSortOrder"
        static let notificationsEnabled = "notificationsEnabled"
        static let disabledSourceCategories = "disabledSourceCategories"
        static let lastUpdatedAt = "lastUpdatedAt"
        static let hasSeenIntro = "hasSeenIntro"
        static let topStoryDismissedAt = "topStoryDismissedAt"
        static let blockedUserIds = "blockedUserIds"
    }

    private static let topStoryDismissalWindow: TimeInterval = 24 * 60 * 60

    private let contentSourceClient: any ContentSourceClient

    let translator = ContentTranslator()
    let authService = AuthService()
    let profileService = ProfileService()
    let communityService = CommunityService()

    var selectedTopics: Set<Topic> = []
    var focusedTopic: Topic?
    var currentTab: AppTab = .home
    var savedItemSnapshots: [URL: ContentItem] = [:]
    var savedItemTimestampsByURL: [URL: Date] = [:]
    var savedSortOrder: SavedSortOrder = .recentlySaved
    var notificationsEnabled = false
    var disabledSourceCategories: Set<SourceCategory> = []
    var blockedUserIds: Set<String> = []
    var allItems: [ContentItem] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdatedAt: Date?
    var hasSeenIntro = false
    var topStoryDismissedAt: Date?
    var visibleItemLimit: Int = pageSize
    var homeScrollToTopTrigger = 0
    var communityScrollToTopTrigger = 0
    var savedScrollToTopTrigger = 0
    var settingsScrollToTopTrigger = 0

    var isTopStoryHidden: Bool {
        guard let topStoryDismissedAt else {
            return false
        }
        return Date().timeIntervalSince(topStoryDismissedAt) < Self.topStoryDismissalWindow
    }

    var savedURLs: Set<URL> {
        Set(savedItemSnapshots.keys)
    }

    var savedItemIDs: Set<ContentItem.ID> {
        let urls = savedURLs
        return Set(allItems.filter { urls.contains($0.url) }.map(\.id))
    }

    func isSaved(_ item: ContentItem) -> Bool {
        savedItemSnapshots[item.url] != nil
    }

    init(contentSourceClient: (any ContentSourceClient)? = nil) {
        self.contentSourceClient = contentSourceClient ?? Self.defaultContentSourceClient()
        loadPersistedState()
    }

    var isOnboardingComplete: Bool {
        !selectedTopics.isEmpty
    }

    var personalizedItems: [ContentItem] {
        let enabledByCategory = allItems.filter { !disabledSourceCategories.contains($0.sourceCategory) }
        let activeTopics: Set<Topic>
        if let focusedTopic, selectedTopics.contains(focusedTopic) {
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

        let savedSourceCounts = savedSourceNameCounts()

        return filteredItems.sorted { lhs, rhs in
            let leftScore = personalizedScore(for: lhs, savedSourceCounts: savedSourceCounts)
            let rightScore = personalizedScore(for: rhs, savedSourceCounts: savedSourceCounts)
            if leftScore == rightScore {
                return lhs.publishedAt > rhs.publishedAt
            }
            return leftScore > rightScore
        }
    }

    private func personalizedScore(for item: ContentItem, savedSourceCounts: [String: Int]) -> Int {
        let saveBonus = min(8, (savedSourceCounts[item.sourceName] ?? 0) * 2)
        return min(100, item.trendScore + saveBonus)
    }

    private func savedSourceNameCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in savedItemSnapshots.values {
            counts[item.sourceName, default: 0] += 1
        }
        return counts
    }

    var savedItems: [ContentItem] {
        let items = Array(savedItemSnapshots.values)
        switch savedSortOrder {
        case .recentlySaved:
            return items.sorted { lhs, rhs in
                let lhsDate = savedItemTimestampsByURL[lhs.url] ?? .distantPast
                let rhsDate = savedItemTimestampsByURL[rhs.url] ?? .distantPast
                return lhsDate > rhsDate
            }
        case .trending:
            return items.sorted { lhs, rhs in
                if lhs.trendScore == rhs.trendScore {
                    return lhs.publishedAt > rhs.publishedAt
                }
                return lhs.trendScore > rhs.trendScore
            }
        }
    }

    func isSourceCategoryEnabled(_ category: SourceCategory) -> Bool {
        !disabledSourceCategories.contains(category)
    }

    func setSourceCategory(_ category: SourceCategory, enabled: Bool) {
        if enabled {
            disabledSourceCategories.remove(category)
        }
        else {
            disabledSourceCategories.insert(category)
        }
        resetPagination()
        persistState()
    }

    var articleItems: [ContentItem] {
        personalizedItems.filter { $0.kind == .article }
    }

    var discussionItems: [ContentItem] {
        personalizedItems.filter { $0.kind == .discussion }
    }

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

    private func resetPagination() {
        visibleItemLimit = Self.pageSize
    }

    var savedArticleItems: [ContentItem] {
        savedItems.filter { $0.kind == .article }
    }

    var savedDiscussionItems: [ContentItem] {
        savedItems.filter { $0.kind == .discussion }
    }

    var hasLoadedContent: Bool {
        !allItems.isEmpty
    }

    var canSelectMoreTopics: Bool {
        selectedTopics.count < Self.maxSelectedTopics
    }

    func toggleTopic(_ topic: Topic) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
            if focusedTopic == topic {
                focusedTopic = nil
            }
        }
        else {
            guard canSelectMoreTopics else {
                return
            }
            selectedTopics.insert(topic)
        }

        resetPagination()
        persistState()
    }

    func toggleFocusedTopic(_ topic: Topic) {
        if focusedTopic == topic {
            focusedTopic = nil
        }
        else if selectedTopics.contains(topic) {
            focusedTopic = topic
        }
        resetPagination()
    }

    func clearFocusedTopic() {
        focusedTopic = nil
        resetPagination()
    }

    func addSavedItem(_ item: ContentItem) {
        savedItemSnapshots[item.url] = item
        savedItemTimestampsByURL[item.url] = .now
        persistState()
    }

    func updateSavedItem(_ item: ContentItem) {
        guard savedItemSnapshots[item.url] != nil else { return }
        savedItemSnapshots[item.url] = item
        persistState()
    }

    func removeSavedItem(at url: URL) {
        savedItemSnapshots[url] = nil
        savedItemTimestampsByURL[url] = nil
        persistState()
    }


    func blockUser(_ userId: String) {
        blockedUserIds.insert(userId)
        persistState()
    }

    func unblockUser(_ userId: String) {
        blockedUserIds.remove(userId)
        persistState()
    }

    func toggleSaved(_ item: ContentItem) {
        if savedItemSnapshots[item.url] != nil {
            savedItemSnapshots[item.url] = nil
            savedItemTimestampsByURL[item.url] = nil
        }
        else {
            savedItemSnapshots[item.url] = item
            savedItemTimestampsByURL[item.url] = .now
        }

        persistState()
    }

    func setSavedSortOrder(_ order: SavedSortOrder) {
        guard savedSortOrder != order else {
            return
        }
        savedSortOrder = order
        persistState()
    }

    func markIntroSeen() {
        hasSeenIntro = true
        persistState()
    }

    func dismissTopStory() {
        topStoryDismissedAt = .now
        persistState()
    }

    func resetTopics() {
        selectedTopics.removeAll()
        focusedTopic = nil
        resetPagination()
        persistState()
    }

    func notifyTabSelected(_ tab: AppTab) {
        if tab == currentTab {
            switch tab {
            case .home: homeScrollToTopTrigger &+= 1
            case .community: communityScrollToTopTrigger &+= 1
            case .saved: savedScrollToTopTrigger &+= 1
            case .settings: settingsScrollToTopTrigger &+= 1
            }
        }
        else {
            currentTab = tab
        }
    }

    func setNotificationsEnabled(_ isEnabled: Bool) {
        guard notificationsEnabled != isEnabled else {
            return
        }
        notificationsEnabled = isEnabled
        persistState()
    }

    func loadIfNeeded() async {
        guard !hasLoadedContent, !isLoading else {
            return
        }

        await reload()
    }

    func refreshIfStale(maxAge: TimeInterval) async {
        guard !isLoading else {
            return
        }

        if let lastUpdatedAt, Date().timeIntervalSince(lastUpdatedAt) < maxAge, hasLoadedContent {
            return
        }

        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil

        do {
            allItems = try await contentSourceClient.fetchItems()
            lastUpdatedAt = .now
            resetPagination()
            persistState()
        }
        catch {
            errorMessage = String(localized: "error.unableToLoad")
        }

        isLoading = false
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard

        if let storedTopicValues = defaults.stringArray(forKey: StorageKey.selectedTopics) {
            selectedTopics = Set(storedTopicValues.compactMap(Topic.init(rawValue:)))
        }

        if let snapshotData = defaults.data(forKey: StorageKey.savedItemSnapshots),
           let decoded = try? JSONDecoder().decode([SavedRecord].self, from: snapshotData) {
            for record in decoded {
                savedItemSnapshots[record.item.url] = record.item
                savedItemTimestampsByURL[record.item.url] = record.savedAt
            }
        }

        if let storedSortOrder = defaults.string(forKey: StorageKey.savedSortOrder),
           let order = SavedSortOrder(rawValue: storedSortOrder) {
            savedSortOrder = order
        }

        if defaults.object(forKey: StorageKey.notificationsEnabled) != nil {
            notificationsEnabled = defaults.bool(forKey: StorageKey.notificationsEnabled)
        }

        if let storedDisabled = defaults.stringArray(forKey: StorageKey.disabledSourceCategories) {
            disabledSourceCategories = Set(storedDisabled.compactMap(SourceCategory.init(rawValue:)))
        }

        if let storedBlocked = defaults.stringArray(forKey: StorageKey.blockedUserIds) {
            blockedUserIds = Set(storedBlocked)
        }


        if let storedTimestamp = defaults.object(forKey: StorageKey.lastUpdatedAt) as? Date {
            lastUpdatedAt = storedTimestamp
        }

        if defaults.object(forKey: StorageKey.hasSeenIntro) != nil {
            hasSeenIntro = defaults.bool(forKey: StorageKey.hasSeenIntro)
        }

        if let storedDismissedAt = defaults.object(forKey: StorageKey.topStoryDismissedAt) as? Date {
            topStoryDismissedAt = storedDismissedAt
        }
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        let topicValues = selectedTopics.map(\.rawValue).sorted()
        let disabledCategoryValues = disabledSourceCategories.map(\.rawValue).sorted()
        let records = savedItemSnapshots.values.map { item in
            SavedRecord(item: item, savedAt: savedItemTimestampsByURL[item.url] ?? .now)
        }

        defaults.set(topicValues, forKey: StorageKey.selectedTopics)
        if let encoded = try? JSONEncoder().encode(records) {
            defaults.set(encoded, forKey: StorageKey.savedItemSnapshots)
        }
        defaults.set(savedSortOrder.rawValue, forKey: StorageKey.savedSortOrder)
        defaults.set(notificationsEnabled, forKey: StorageKey.notificationsEnabled)
        defaults.set(disabledCategoryValues, forKey: StorageKey.disabledSourceCategories)
        defaults.set(Array(blockedUserIds), forKey: StorageKey.blockedUserIds)
        defaults.set(lastUpdatedAt, forKey: StorageKey.lastUpdatedAt)
        defaults.set(hasSeenIntro, forKey: StorageKey.hasSeenIntro)
        defaults.set(topStoryDismissedAt, forKey: StorageKey.topStoryDismissedAt)
    }

    private struct SavedRecord: Codable {
        let item: ContentItem
        let savedAt: Date
    }

    private static func defaultContentSourceClient() -> any ContentSourceClient {
        CompositeContentSourceClient(
            clients: [
                RSSSourceClient(),
                DevToSourceClient(),
                GitHubTrendingSourceClient(),
                HackerNewsSourceClient(),
                RedditSourceClient()
            ],
            fallbackClient: MockContentSourceClient()
        )
    }
}
