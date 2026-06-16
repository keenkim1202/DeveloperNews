import Foundation

/// Owns all app-group `UserDefaults` persistence for `AppState`.
///
/// Runs as an `actor` so the heavy JSON encoding (saved-item snapshots, the full
/// `allItems` feed) happens off the main actor. `UserDefaults` writes are
/// thread-safe, and the suite handle is cached once instead of being recreated
/// on every write. Reads happen synchronously at launch via `load()`.
actor PersistenceStore {
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
        static let readItemURLs = "readItemURLs"
        static let readPostIds = "readPostIds"
        static let translationLanguage = "translationLanguage"
        static let allItems = "allItems"
    }

    struct SavedRecord: Codable {
        let item: ContentItem
        let savedAt: Date
    }

    /// Snapshot of everything decoded from disk at launch.
    struct LoadedState {
        var selectedTopics: Set<Topic> = []
        var savedItemSnapshots: [URL: ContentItem] = [:]
        var savedItemTimestampsByURL: [URL: Date] = [:]
        var savedSortOrder: SavedSortOrder = .recentlySaved
        var notificationsEnabled = false
        var disabledSourceCategories: Set<SourceCategory> = []
        var blockedUserIds: Set<String> = []
        var readItemURLs: Set<String> = []
        var readPostIds: Set<String> = []
        var translationLanguage: String?
        var lastUpdatedAt: Date?
        var hasSeenIntro = false
        var topStoryDismissedAt: Date?
        var allItems: [ContentItem] = []
    }

    // UserDefaults is thread-safe but not Sendable, so this handle is safe to touch
    // from both the nonisolated `load()` and the actor-isolated writes.
    private nonisolated(unsafe) let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "group.keen-onit.DeveloperNews") ?? .standard
    }

    // MARK: - Load

    /// Decodes the full persisted state. Synchronous decode is acceptable at launch.
    /// `nonisolated` so callers can read without hopping onto the actor.
    nonisolated func load() -> LoadedState {
        var state = LoadedState()

        if let storedTopicValues = defaults.stringArray(forKey: StorageKey.selectedTopics) {
            state.selectedTopics = Set(storedTopicValues.compactMap(Topic.init(rawValue:)))
        }

        if let snapshotData = defaults.data(forKey: StorageKey.savedItemSnapshots),
           let decoded = try? JSONDecoder().decode([SavedRecord].self, from: snapshotData) {
            for record in decoded {
                state.savedItemSnapshots[record.item.url] = record.item
                state.savedItemTimestampsByURL[record.item.url] = record.savedAt
            }
        }

        if let storedSortOrder = defaults.string(forKey: StorageKey.savedSortOrder),
           let order = SavedSortOrder(rawValue: storedSortOrder) {
            state.savedSortOrder = order
        }

        if defaults.object(forKey: StorageKey.notificationsEnabled) != nil {
            state.notificationsEnabled = defaults.bool(forKey: StorageKey.notificationsEnabled)
        }

        if let storedDisabled = defaults.stringArray(forKey: StorageKey.disabledSourceCategories) {
            state.disabledSourceCategories = Set(storedDisabled.compactMap(SourceCategory.init(rawValue:)))
        }

        if let storedBlocked = defaults.stringArray(forKey: StorageKey.blockedUserIds) {
            state.blockedUserIds = Set(storedBlocked)
        }

        if let storedReadURLs = defaults.stringArray(forKey: StorageKey.readItemURLs) {
            state.readItemURLs = Set(storedReadURLs)
        }

        if let storedReadPosts = defaults.stringArray(forKey: StorageKey.readPostIds) {
            state.readPostIds = Set(storedReadPosts)
        }

        if let storedLang = defaults.string(forKey: StorageKey.translationLanguage) {
            state.translationLanguage = storedLang
        }

        if let storedTimestamp = defaults.object(forKey: StorageKey.lastUpdatedAt) as? Date {
            state.lastUpdatedAt = storedTimestamp
        }

        if defaults.object(forKey: StorageKey.hasSeenIntro) != nil {
            state.hasSeenIntro = defaults.bool(forKey: StorageKey.hasSeenIntro)
        }

        if let storedDismissedAt = defaults.object(forKey: StorageKey.topStoryDismissedAt) as? Date {
            state.topStoryDismissedAt = storedDismissedAt
        }

        if let storedItemsData = defaults.data(forKey: StorageKey.allItems),
           let decoded = try? JSONDecoder().decode([ContentItem].self, from: storedItemsData) {
            state.allItems = decoded
        }

        return state
    }

    // MARK: - Targeted writes

    func saveTopics(_ topics: Set<Topic>) {
        let values = topics.map(\.rawValue).sorted()
        defaults.set(values, forKey: StorageKey.selectedTopics)
    }

    func saveSavedItems(
        snapshots: [URL: ContentItem],
        timestamps: [URL: Date],
    ) {
        let records = snapshots.values.map { item in
            SavedRecord(item: item, savedAt: timestamps[item.url] ?? .now)
        }
        if let encoded = try? JSONEncoder().encode(records) {
            defaults.set(encoded, forKey: StorageKey.savedItemSnapshots)
        }
    }

    func saveSortOrder(_ order: SavedSortOrder) {
        defaults.set(order.rawValue, forKey: StorageKey.savedSortOrder)
    }

    func saveNotificationsEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: StorageKey.notificationsEnabled)
    }

    func saveDisabledSourceCategories(_ categories: Set<SourceCategory>) {
        let values = categories.map(\.rawValue).sorted()
        defaults.set(values, forKey: StorageKey.disabledSourceCategories)
    }

    func saveBlockedUsers(_ userIds: Set<String>) {
        defaults.set(Array(userIds), forKey: StorageKey.blockedUserIds)
    }

    func saveReadItems(
        readItemURLs: Set<String>,
        readPostIds: Set<String>,
    ) {
        defaults.set(Array(readItemURLs), forKey: StorageKey.readItemURLs)
        defaults.set(Array(readPostIds), forKey: StorageKey.readPostIds)
    }

    func saveTranslationLanguage(_ code: String?) {
        defaults.set(code, forKey: StorageKey.translationLanguage)
    }

    func saveLastUpdatedAt(_ date: Date?) {
        defaults.set(date, forKey: StorageKey.lastUpdatedAt)
    }

    func saveHasSeenIntro(_ value: Bool) {
        defaults.set(value, forKey: StorageKey.hasSeenIntro)
    }

    func saveTopStoryDismissedAt(_ date: Date?) {
        defaults.set(date, forKey: StorageKey.topStoryDismissedAt)
    }

    func saveAllItems(_ items: [ContentItem]) {
        if let encoded = try? JSONEncoder().encode(items) {
            defaults.set(encoded, forKey: StorageKey.allItems)
        }
    }
}
