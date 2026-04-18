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
        static let readItemURLs = "readItemURLs"
        static let readPostIds = "readPostIds"
        static let translationLanguage = "translationLanguage"
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
    var readItemURLs: Set<String> = []
    var readPostIds: Set<String> = []
    var allItems: [ContentItem] = []
    var isLoading = false
    var errorMessage: String?
    var failedSourceNames: [String] = []
    var toastMessage: String?
    var toastTrigger: Int = 0
    var lastUpdatedAt: Date?

    @ObservationIgnored
    private var reloadGeneration: Int = 0
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

    var followingItems: [ContentItem] {
        guard !disabledSourceCategories.contains(.following) else { return [] }
        let followedIds = profileService.followedUserIds
        guard !followedIds.isEmpty else { return [] }

        return communityService.posts
            .filter { followedIds.contains($0.authorId) }
            .map { post in
                ContentItem(
                    id: UUID(uuidString: post.id) ?? UUID(),
                    kind: .article,
                    title: post.title,
                    summary: post.description,
                    sourceName: post.authorName,
                    sourceCategory: .following,
                    authorName: post.authorName,
                    url: URL(string: "devnews://community/\(post.id)")!,
                    publishedAt: post.createdAt,
                    topics: post.topics,
                    trendScore: post.likeCount)
            }
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


    private static let maxReadItems = 5000

    func setTranslationLanguage(_ code: String?) {
        translator.targetLanguageCode = code
        persistState()
    }

    func markURLAsRead(_ urlString: String) {
        readItemURLs.insert(HashUtil.shortHash(urlString))
        trimReadItems()
        persistState()
    }

    func markAsRead(_ item: ContentItem) {
        readItemURLs.insert(HashUtil.shortHash(item.url.absoluteString))
        trimReadItems()
        persistState()
    }

    func isRead(_ item: ContentItem) -> Bool {
        readItemURLs.contains(HashUtil.shortHash(item.url.absoluteString))
    }

    func markPostAsRead(_ postId: String) {
        readPostIds.insert(HashUtil.shortHash(postId))
        trimReadItems()
        persistState()
    }

    func isPostRead(_ postId: String) -> Bool {
        readPostIds.contains(HashUtil.shortHash(postId))
    }

    private func trimReadItems() {
        if readItemURLs.count > Self.maxReadItems {
            let excess = readItemURLs.count - Self.maxReadItems
            readItemURLs = Set(readItemURLs.dropFirst(excess))
        }
        if readPostIds.count > Self.maxReadItems {
            let excess = readPostIds.count - Self.maxReadItems
            readPostIds = Set(readPostIds.dropFirst(excess))
        }
    }

    func blockUser(_ userId: String) {
        blockedUserIds.insert(userId)
        persistState()
    }

    func unblockUser(_ userId: String) {
        blockedUserIds.remove(userId)
        persistState()
    }

    @discardableResult
    func deleteCurrentAccount() async -> DeleteAccountResult {
        guard let uid = authService.userId else { return .failed }

        profileService.stopListening()

        do {
            try await communityService.deleteUserContent(uid: uid)
            try await profileService.deleteOwnProfile(uid: uid)
        }
        catch {
            authService.setErrorMessage(error.localizedDescription)
            return .failed
        }

        return await authService.deleteAccount()
    }

    func updateDisplayName(_ name: String) async {
        await profileService.updateDisplayName(name)
    }

    func updateProfileEmoji(_ emoji: String) async {
        await profileService.updateProfileEmoji(emoji)
    }

    func signOut() {
        profileService.stopListening()
        authService.signOut()
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

    func processPendingSharedItems() {
        let defaults = UserDefaults(suiteName: "group.keen-onit.DeveloperNews") ?? .standard
        guard let pending = defaults.array(forKey: "pendingSharedItems") as? [[String: String]],
              !pending.isEmpty
        else { return }

        for entry in pending {
            guard let urlString = entry["url"], let url = URL(string: urlString) else { continue }
            let title = entry["title"] ?? urlString
            let description = entry["description"] ?? ""
            let topicStrings = (entry["topics"] ?? "").split(separator: ",").map(String.init)
            let topics = topicStrings.compactMap(Topic.init(rawValue:))

            let item = ContentItem(
                id: UUID(),
                kind: .article,
                title: title,
                summary: description,
                sourceName: String(localized: .saveSharedItem),
                sourceCategory: .article,
                authorName: nil,
                url: url,
                publishedAt: .now,
                topics: topics,
                trendScore: 0)
            addSavedItem(item)
        }

        defaults.removeObject(forKey: "pendingSharedItems")
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

        await reload(notifyOnFailure: false)
    }

    func reload(notifyOnFailure: Bool = true) async {
        reloadGeneration += 1
        let generation = reloadGeneration
        isLoading = true
        errorMessage = nil

        let result = await contentSourceClient.fetchItemsWithStatus(selectedTopics: selectedTopics)

        guard generation == reloadGeneration else {
            return
        }

        allItems = result.items
        failedSourceNames = result.failedSourceNames
        lastUpdatedAt = .now
        resetPagination()
        persistState()

        if result.totalSourceCount > 0,
           result.failedSourceNames.count == result.totalSourceCount,
           result.items.isEmpty {
            errorMessage = String(localized: .errorUnableToLoad)
        }

        if notifyOnFailure, !result.failedSourceNames.isEmpty {
            toastMessage = String(localized: .toastSourcesUnavailable)
            toastTrigger += 1
        }

        isLoading = false
    }

    private func loadPersistedState() {
        let defaults = UserDefaults(suiteName: "group.keen-onit.DeveloperNews") ?? .standard

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

        if let storedReadURLs = defaults.stringArray(forKey: StorageKey.readItemURLs) {
            readItemURLs = Set(storedReadURLs)
        }

        if let storedReadPosts = defaults.stringArray(forKey: StorageKey.readPostIds) {
            readPostIds = Set(storedReadPosts)
        }

        if let storedLang = defaults.string(forKey: StorageKey.translationLanguage) {
            translator.targetLanguageCode = storedLang
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
        let defaults = UserDefaults(suiteName: "group.keen-onit.DeveloperNews") ?? .standard
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
        defaults.set(Array(readItemURLs), forKey: StorageKey.readItemURLs)
        defaults.set(Array(readPostIds), forKey: StorageKey.readPostIds)
        defaults.set(translator.targetLanguageCode, forKey: StorageKey.translationLanguage)
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
            namedClients: [
                .init(name: "Blogs & articles", client: RSSSourceClient()),
                .init(name: "DEV.to", client: DevToSourceClient()),
                .init(name: "GitHub Trending", client: GitHubTrendingSourceClient()),
                .init(name: "Hacker News", client: HackerNewsSourceClient()),
                .init(name: "Reddit", client: RedditSourceClient())
            ])
    }
}
