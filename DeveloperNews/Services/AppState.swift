import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    static let maxSelectedTopics = 5
    static let pageSize = 30

    private static let topStoryDismissalWindow: TimeInterval = 24 * 60 * 60
    static let feedStaleThreshold: TimeInterval = 15 * 60

    private let contentSourceClient: any ContentSourceClient
    private let persistenceStore = PersistenceStore()

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

    private func personalizedScore(
        for item: ContentItem,
        savedSourceCounts: [String: Int],
    ) -> Int {
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

    func setSourceCategory(
        _ category: SourceCategory,
        enabled: Bool,
    ) {
        if enabled {
            disabledSourceCategories.remove(category)
        }
        else {
            disabledSourceCategories.insert(category)
        }
        resetPagination()
        saveDisabledSourceCategories()
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

    /// Looks up a `ContentItem` by url across saved items and personalized feed.
    /// URL is the stable identifier across app restarts (unlike `id`, which is regenerated per fetch).
    /// Returns nil if the item has been removed from both sources.
    func resolveItem(url: URL) -> ContentItem? {
        if let snapshot = savedItemSnapshots[url] {
            return snapshot
        }
        return personalizedItems.first { $0.url == url }
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
        saveTopics()
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
        saveSavedItems()
    }

    func updateSavedItem(_ item: ContentItem) {
        guard savedItemSnapshots[item.url] != nil else { return }
        savedItemSnapshots[item.url] = item
        saveSavedItems()
    }

    func removeSavedItem(at url: URL) {
        savedItemSnapshots[url] = nil
        savedItemTimestampsByURL[url] = nil
        saveSavedItems()
    }


    private static let maxReadItems = 5000

    func setTranslationLanguage(_ code: String?) {
        translator.targetLanguageCode = code
        saveTranslationLanguage()
    }

    func markURLAsRead(_ urlString: String) {
        readItemURLs.insert(HashUtil.shortHash(urlString))
        trimReadItems()
        saveReadItems()
    }

    func markAsRead(_ item: ContentItem) {
        readItemURLs.insert(HashUtil.shortHash(item.url.absoluteString))
        trimReadItems()
        saveReadItems()
    }

    func isRead(_ item: ContentItem) -> Bool {
        readItemURLs.contains(HashUtil.shortHash(item.url.absoluteString))
    }

    func markPostAsRead(_ postId: String) {
        readPostIds.insert(HashUtil.shortHash(postId))
        trimReadItems()
        saveReadItems()
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
        saveBlockedUsers()
    }

    func unblockUser(_ userId: String) {
        blockedUserIds.remove(userId)
        saveBlockedUsers()
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

        saveSavedItems()
    }

    func setSavedSortOrder(_ order: SavedSortOrder) {
        guard savedSortOrder != order else {
            return
        }
        savedSortOrder = order
        saveSortOrder()
    }

    func markIntroSeen() {
        hasSeenIntro = true
        saveHasSeenIntro()
    }

    func dismissTopStory() {
        topStoryDismissedAt = .now
        saveTopStoryDismissedAt()
    }

    func resetTopics() {
        selectedTopics.removeAll()
        focusedTopic = nil
        resetPagination()
        saveTopics()
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
        saveNotificationsEnabled()
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

        let result = await contentSourceClient.fetchItemsWithStatus(selectedTopics: selectedTopics)

        guard generation == reloadGeneration else {
            return
        }

        let isFullFailure = result.totalSourceCount > 0 &&
            result.failedSourceNames.count == result.totalSourceCount &&
            result.items.isEmpty

        failedSourceNames = result.failedSourceNames

        if isFullFailure, hadLoadedContent {
            if notifyOnFailure {
                toastMessage = String(localized: .toastSourcesUnavailable)
                toastTrigger += 1
            }
            isLoading = false
            return
        }

        allItems = result.items
        lastUpdatedAt = .now
        resetPagination()
        saveLastUpdatedAt()
        saveAllItems()

        if isFullFailure {
            errorMessage = String(localized: .errorUnableToLoad)
        }

        if notifyOnFailure, !result.failedSourceNames.isEmpty {
            toastMessage = String(localized: .toastSourcesUnavailable)
            toastTrigger += 1
        }

        isLoading = false
    }

    private func loadPersistedState() {
        let state = persistenceStore.load()
        selectedTopics = state.selectedTopics
        savedItemSnapshots = state.savedItemSnapshots
        savedItemTimestampsByURL = state.savedItemTimestampsByURL
        savedSortOrder = state.savedSortOrder
        notificationsEnabled = state.notificationsEnabled
        disabledSourceCategories = state.disabledSourceCategories
        blockedUserIds = state.blockedUserIds
        readItemURLs = state.readItemURLs
        readPostIds = state.readPostIds
        translator.targetLanguageCode = state.translationLanguage
        lastUpdatedAt = state.lastUpdatedAt
        hasSeenIntro = state.hasSeenIntro
        topStoryDismissedAt = state.topStoryDismissedAt
        allItems = state.allItems
    }

    // MARK: - Persistence delegates

    private func saveTopics() {
        let topics = selectedTopics
        Task {
            await persistenceStore.saveTopics(topics)
        }
    }

    private func saveSavedItems() {
        let snapshots = savedItemSnapshots
        let timestamps = savedItemTimestampsByURL
        Task {
            await persistenceStore.saveSavedItems(
                snapshots: snapshots,
                timestamps: timestamps)
        }
    }

    private func saveSortOrder() {
        let order = savedSortOrder
        Task {
            await persistenceStore.saveSortOrder(order)
        }
    }

    private func saveNotificationsEnabled() {
        let isEnabled = notificationsEnabled
        Task {
            await persistenceStore.saveNotificationsEnabled(isEnabled)
        }
    }

    private func saveDisabledSourceCategories() {
        let categories = disabledSourceCategories
        Task {
            await persistenceStore.saveDisabledSourceCategories(categories)
        }
    }

    private func saveBlockedUsers() {
        let userIds = blockedUserIds
        Task {
            await persistenceStore.saveBlockedUsers(userIds)
        }
    }

    private func saveReadItems() {
        let urls = readItemURLs
        let postIds = readPostIds
        Task {
            await persistenceStore.saveReadItems(
                readItemURLs: urls,
                readPostIds: postIds)
        }
    }

    private func saveTranslationLanguage() {
        let code = translator.targetLanguageCode
        Task {
            await persistenceStore.saveTranslationLanguage(code)
        }
    }

    private func saveLastUpdatedAt() {
        let date = lastUpdatedAt
        Task {
            await persistenceStore.saveLastUpdatedAt(date)
        }
    }

    private func saveHasSeenIntro() {
        let value = hasSeenIntro
        Task {
            await persistenceStore.saveHasSeenIntro(value)
        }
    }

    private func saveTopStoryDismissedAt() {
        let date = topStoryDismissedAt
        Task {
            await persistenceStore.saveTopStoryDismissedAt(date)
        }
    }

    private func saveAllItems() {
        let items = allItems
        Task {
            await persistenceStore.saveAllItems(items)
        }
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
