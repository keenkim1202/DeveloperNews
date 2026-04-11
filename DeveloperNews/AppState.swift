import Foundation
import Observation

@Observable
final class AppState {
    static let maxSelectedTopics = 5

    private enum StorageKey {
        static let selectedTopics = "selectedTopics"
        static let savedItemIDs = "savedItemIDs"
        static let notificationsEnabled = "notificationsEnabled"
        static let disabledSourceCategories = "disabledSourceCategories"
        static let lastUpdatedAt = "lastUpdatedAt"
    }

    private let contentSourceClient: any ContentSourceClient

    var selectedTopics: Set<Topic> = []
    var savedItemIDs: Set<ContentItem.ID> = []
    var notificationsEnabled = false
    var disabledSourceCategories: Set<SourceCategory> = []
    var allItems: [ContentItem] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdatedAt: Date?

    init(contentSourceClient: (any ContentSourceClient)? = nil) {
        self.contentSourceClient = contentSourceClient ?? Self.defaultContentSourceClient()
        loadPersistedState()
    }

    var isOnboardingComplete: Bool {
        !selectedTopics.isEmpty
    }

    var personalizedItems: [ContentItem] {
        let enabledByCategory = allItems.filter { !disabledSourceCategories.contains($0.sourceCategory) }
        let filteredItems: [ContentItem]
        if selectedTopics.isEmpty {
            filteredItems = enabledByCategory
        }
        else {
            filteredItems = enabledByCategory.filter { item in
                !selectedTopics.isDisjoint(with: item.topics)
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
        for item in allItems where savedItemIDs.contains(item.id) {
            counts[item.sourceName, default: 0] += 1
        }
        return counts
    }

    var savedItems: [ContentItem] {
        allItems.filter { savedItemIDs.contains($0.id) }
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
        persistState()
    }

    var articleItems: [ContentItem] {
        personalizedItems.filter { $0.kind == .article }
    }

    var discussionItems: [ContentItem] {
        personalizedItems.filter { $0.kind == .discussion }
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
        }
        else {
            guard canSelectMoreTopics else {
                return
            }
            selectedTopics.insert(topic)
        }

        persistState()
    }

    func toggleSaved(itemID: ContentItem.ID) {
        if savedItemIDs.contains(itemID) {
            savedItemIDs.remove(itemID)
        }
        else {
            savedItemIDs.insert(itemID)
        }

        persistState()
    }

    func resetTopics() {
        selectedTopics.removeAll()
        persistState()
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
            persistState()
        }
        catch {
            errorMessage = "Unable to load stories right now."
        }

        isLoading = false
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard

        if let storedTopicValues = defaults.stringArray(forKey: StorageKey.selectedTopics) {
            selectedTopics = Set(storedTopicValues.compactMap(Topic.init(rawValue:)))
        }

        if let storedSavedIDs = defaults.stringArray(forKey: StorageKey.savedItemIDs) {
            savedItemIDs = Set(storedSavedIDs.compactMap(UUID.init(uuidString:)))
        }

        if defaults.object(forKey: StorageKey.notificationsEnabled) != nil {
            notificationsEnabled = defaults.bool(forKey: StorageKey.notificationsEnabled)
        }

        if let storedDisabled = defaults.stringArray(forKey: StorageKey.disabledSourceCategories) {
            disabledSourceCategories = Set(storedDisabled.compactMap(SourceCategory.init(rawValue:)))
        }

        if let storedTimestamp = defaults.object(forKey: StorageKey.lastUpdatedAt) as? Date {
            lastUpdatedAt = storedTimestamp
        }
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        let topicValues = selectedTopics.map(\.rawValue).sorted()
        let savedIDs = savedItemIDs.map(\.uuidString).sorted()
        let disabledCategoryValues = disabledSourceCategories.map(\.rawValue).sorted()

        defaults.set(topicValues, forKey: StorageKey.selectedTopics)
        defaults.set(savedIDs, forKey: StorageKey.savedItemIDs)
        defaults.set(notificationsEnabled, forKey: StorageKey.notificationsEnabled)
        defaults.set(disabledCategoryValues, forKey: StorageKey.disabledSourceCategories)
        defaults.set(lastUpdatedAt, forKey: StorageKey.lastUpdatedAt)
    }

    private static func defaultContentSourceClient() -> any ContentSourceClient {
        CompositeContentSourceClient(
            clients: [
                RSSSourceClient(),
                HackerNewsSourceClient(),
                RedditSourceClient()
            ],
            fallbackClient: MockContentSourceClient()
        )
    }
}
