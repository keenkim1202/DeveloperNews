import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    static let maxSelectedTopics = 5

    private static let topStoryDismissalWindow: TimeInterval = 24 * 60 * 60
    static let feedStaleThreshold: TimeInterval = FeedStore.feedStaleThreshold

    private let contentSourceClient: any ContentSourceClient
    private let persistenceStore: PersistenceStore
    private var persistenceChain: Task<Void, Never> = Task {}

    private(set) var feedStore: FeedStore!
    private(set) var savedItemsStore: SavedItemsStore!
    private(set) var readTracker: ReadTracker!
    private(set) var sourceCategoryStore: SourceCategoryStore!
    private(set) var offlineArticleStore: OfflineArticleStore!

    let translator: any Translating
    let authService: any AuthServicing
    let profileService: any ProfileServicing
    let communityService: any CommunityServicing
    let feedPostService: any FeedPostServicing
    let storyEngagementService: any StoryEngagementServicing
    let activityService: any ActivityServicing
    let notificationScheduler: any NotificationScheduling
    let articleSummarizer: any ArticleSummarizing

    var selectedTopics: Set<Topic> = []
    var focusedTopic: Topic?
    var currentTab: AppTab = .home
    var notificationsEnabled = false
    var blockedUserIds: Set<String> = []
    var toastMessage: String?
    var toastTrigger: Int = 0
    var hasSeenIntro = false
    var topStoryDismissedAt: Date?
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

    var savedItemSnapshots: [URL: ContentItem] {
        savedItemsStore.savedItemSnapshots
    }

    var savedItemTimestampsByURL: [URL: Date] {
        savedItemsStore.savedItemTimestampsByURL
    }

    var savedSortOrder: SavedSortOrder {
        savedItemsStore.savedSortOrder
    }

    var savedURLs: Set<URL> {
        savedItemsStore.savedURLs
    }

    var savedItemIDs: Set<ContentItem.ID> {
        savedItemsStore.savedItemIDs
    }

    var disabledSourceCategories: Set<SourceCategory> {
        sourceCategoryStore.disabledSourceCategories
    }

    // MARK: - Feed pass-throughs

    var allItems: [ContentItem] {
        feedStore.allItems
    }

    var isLoading: Bool {
        feedStore.isLoading
    }

    var errorMessage: String? {
        feedStore.errorMessage
    }

    var failedSourceNames: [String] {
        feedStore.failedSourceNames
    }

    var lastUpdatedAt: Date? {
        feedStore.lastUpdatedAt
    }

    var visibleItemLimit: Int {
        feedStore.visibleItemLimit
    }

    var personalizedItems: [ContentItem] {
        feedStore.personalizedItems
    }

    var articleItems: [ContentItem] {
        feedStore.articleItems
    }

    var discussionItems: [ContentItem] {
        feedStore.discussionItems
    }

    var pagedPersonalizedItems: [ContentItem] {
        feedStore.pagedPersonalizedItems
    }

    var pagedArticleItems: [ContentItem] {
        feedStore.pagedArticleItems
    }

    var pagedDiscussionItems: [ContentItem] {
        feedStore.pagedDiscussionItems
    }

    var hasMorePages: Bool {
        feedStore.hasMorePages
    }

    var hasLoadedContent: Bool {
        feedStore.hasLoadedContent
    }

    func loadMore() {
        feedStore.loadMore()
    }

    private func resetPagination() {
        feedStore.resetPagination()
    }

    func loadIfNeeded() async {
        await feedStore.loadIfNeeded()
    }

    func refreshIfStale(maxAge: TimeInterval) async {
        await feedStore.refreshIfStale(maxAge: maxAge)
    }

    func reload(notifyOnFailure: Bool = true) async {
        await feedStore.reload(notifyOnFailure: notifyOnFailure)
    }

    func isSaved(_ item: ContentItem) -> Bool {
        savedItemsStore.isSaved(item)
    }

    init(
        translator: any Translating,
        authService: any AuthServicing,
        profileService: any ProfileServicing,
        communityService: any CommunityServicing,
        feedPostService: any FeedPostServicing,
        storyEngagementService: any StoryEngagementServicing,
        activityService: any ActivityServicing,
        notificationScheduler: any NotificationScheduling,
        articleSummarizer: any ArticleSummarizing,
        contentSourceClient: (any ContentSourceClient)? = nil,
        persistenceStore: PersistenceStore = PersistenceStore(),
    ) {
        self.translator = translator
        self.authService = authService
        self.profileService = profileService
        self.communityService = communityService
        self.feedPostService = feedPostService
        self.storyEngagementService = storyEngagementService
        self.activityService = activityService
        self.notificationScheduler = notificationScheduler
        self.articleSummarizer = articleSummarizer
        self.persistenceStore = persistenceStore
        let client = contentSourceClient ?? Self.defaultContentSourceClient()
        self.contentSourceClient = client
        self.feedStore = FeedStore(
            contentSourceClient: client,
            inputs: FeedStore.Inputs(
                selectedTopics: { [unowned self] in selectedTopics },
                focusedTopic: { [unowned self] in focusedTopic },
                disabledSourceCategories: { [unowned self] in disabledSourceCategories },
                savedItemSnapshots: { [unowned self] in savedItemSnapshots },
                followedUserIds: { [profileService] in profileService.followedUserIds },
                communityPosts: { [communityService] in communityService.posts },
                isFollowingSourceEnabled: { [unowned self] in
                    sourceCategoryStore.isSourceCategoryEnabled(.following)
                },
                persistAllItems: { [unowned self] items in saveAllItems(items) },
                persistLastUpdatedAt: { [unowned self] date in saveLastUpdatedAt(date) },
                showSourcesUnavailableToast: { [unowned self] in showSourcesUnavailableToast() }))
        self.savedItemsStore = SavedItemsStore(
            inputs: SavedItemsStore.Inputs(
                allItems: { [unowned self] in allItems },
                personalizedItems: { [unowned self] in personalizedItems },
                persistSavedItems: { [unowned self] snapshots, timestamps in
                    saveSavedItems(snapshots: snapshots, timestamps: timestamps)
                },
                persistSortOrder: { [unowned self] order in saveSortOrder(order) }))
        self.readTracker = ReadTracker(
            inputs: ReadTracker.Inputs(
                persistReadItems: { [unowned self] urls, postIds in
                    saveReadItems(readItemURLs: urls, readPostIds: postIds)
                },
                persistReadHistory: { [unowned self] history in
                    saveReadHistory(history)
                }))
        self.offlineArticleStore = OfflineArticleStore(
            inputs: OfflineArticleStore.Inputs(
                persistOfflineArticles: { [unowned self] articles in
                    saveOfflineArticles(articles)
                }))
        self.sourceCategoryStore = SourceCategoryStore(
            inputs: SourceCategoryStore.Inputs(
                resetPagination: { [unowned self] in resetPagination() },
                persistDisabledSourceCategories: { [unowned self] categories in
                    saveDisabledSourceCategories(categories)
                }))
        loadPersistedState()
    }

    private func showSourcesUnavailableToast() {
        toastMessage = String(localized: .toastSourcesUnavailable)
        toastTrigger += 1
    }

    func presentError(_ message: String) {
        toastMessage = message
        toastTrigger += 1
    }

    var isOnboardingComplete: Bool {
        !selectedTopics.isEmpty
    }

    var savedItems: [ContentItem] {
        savedItemsStore.savedItems
    }

    func isSourceCategoryEnabled(_ category: SourceCategory) -> Bool {
        sourceCategoryStore.isSourceCategoryEnabled(category)
    }

    func setSourceCategory(
        _ category: SourceCategory,
        enabled: Bool,
    ) {
        sourceCategoryStore.setSourceCategory(category, enabled: enabled)
    }

    var savedArticleItems: [ContentItem] {
        savedItemsStore.savedArticleItems
    }

    var savedDiscussionItems: [ContentItem] {
        savedItemsStore.savedDiscussionItems
    }

    func resolveItem(url: URL) -> ContentItem? {
        savedItemsStore.resolveItem(url: url)
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
        savedItemsStore.addSavedItem(item)
    }

    func updateSavedItem(_ item: ContentItem) {
        savedItemsStore.updateSavedItem(item)
    }

    func removeSavedItem(at url: URL) {
        savedItemsStore.removeSavedItem(at: url)
        offlineArticleStore.removeArticle(for: url)
    }


    var readItemURLs: Set<String> {
        readTracker.readItemURLs
    }

    var readPostIds: Set<String> {
        readTracker.readPostIds
    }

    func setTranslationLanguage(_ code: String?) {
        translator.targetLanguageCode = code
        saveTranslationLanguage()
    }

    func markURLAsRead(_ urlString: String) {
        readTracker.markURLAsRead(urlString)
    }

    func markAsRead(_ item: ContentItem) {
        readTracker.markAsRead(item)
    }

    func isRead(_ item: ContentItem) -> Bool {
        readTracker.isRead(item)
    }

    var readHistory: [ReadRecord] {
        readTracker.readHistory
    }

    func clearReadHistory() {
        readTracker.clearHistory()
    }

    func markPostAsRead(_ postId: String) {
        readTracker.markPostAsRead(postId)
    }

    func isPostRead(_ postId: String) -> Bool {
        readTracker.isPostRead(postId)
    }

    // MARK: - Activity inbox

    /// Activities worth showing: nothing from a blocked user, and nothing whose
    /// actor is the signed-in user, which a stale document could still be.
    var visibleActivities: [Activity] {
        activityService.activities.filter { activity in
            !blockedUserIds.contains(activity.actorId) && activity.actorId != authService.userId
        }
    }

    var unreadActivityCount: Int {
        visibleActivities.count { !$0.isRead }
    }

    func startListeningForActivities() {
        guard let uid = authService.userId else {
            return
        }
        activityService.startListening(userId: uid)
    }

    func stopListeningForActivities() {
        activityService.stopListening()
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
        stopListeningForActivities()

        // Deletion failed partway, so the account still exists and its screens
        // need live data again.
        func restoreListeners() {
            if let user = authService.user {
                profileService.startListening(for: user)
            }
            startListeningForActivities()
        }

        do {
            try await communityService.deleteUserContent(uid: uid)
            // Before the profile document, since deleting it does not take the
            // activities subcollection with it. Rows this user wrote into other
            // inboxes are not reachable from here — the read rule scopes an
            // inbox to its owner — so those are left naming a gone account.
            try await activityService.deleteInbox(userId: uid)
            try await profileService.deleteOwnProfile(uid: uid)
        }
        catch {
            restoreListeners()
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

    func updateBio(_ bio: String) async {
        await profileService.updateBio(bio)
    }

    var profileBio: String? {
        profileService.profileBio
    }

    func signOut() {
        profileService.stopListening()
        authService.signOut()
    }

    func toggleSaved(_ item: ContentItem) {
        savedItemsStore.toggleSaved(item)
        // Unsaving gives back the space its captured text was using.
        if !isSaved(item) {
            offlineArticleStore.removeArticle(for: item.url)
        }
    }

    // MARK: - Offline reading

    func offlineArticle(for url: URL) -> OfflineArticle? {
        offlineArticleStore.article(for: url)
    }

    func hasOfflineArticle(for url: URL) -> Bool {
        offlineArticleStore.hasArticle(for: url)
    }

    /// Keeps the readable text of a saved article. Called once the page has
    /// rendered, which is the only moment the text is available without
    /// fetching and parsing the page a second time.
    func captureOfflineArticle(
        _ item: ContentItem,
        paragraphs: [String],
    ) {
        guard isSaved(item) else {
            return
        }
        offlineArticleStore.store(
            url: item.url,
            title: item.title,
            sourceName: item.sourceName,
            paragraphs: paragraphs)
    }

    func setSavedSortOrder(_ order: SavedSortOrder) {
        savedItemsStore.setSavedSortOrder(order)
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

    /// True once the user has turned the digest on but iOS has refused to
    /// deliver it, which the settings screen turns into a prompt to open the
    /// Settings app. There is nothing the app itself can do about that state.
    var notificationsDeniedBySystem = false

    func setNotificationsEnabled(_ isEnabled: Bool) async {
        guard notificationsEnabled != isEnabled else {
            return
        }

        guard isEnabled else {
            notificationsEnabled = false
            notificationsDeniedBySystem = false
            notificationScheduler.cancelDailyDigest()
            saveNotificationsEnabled()
            return
        }

        // Permission is asked for at the moment it is wanted, rather than on
        // launch, so the prompt arrives with the reason for it on screen.
        let authorization = await notificationScheduler.requestAuthorization()
        guard authorization == .granted else {
            notificationsDeniedBySystem = true
            return
        }

        notificationsDeniedBySystem = false
        notificationsEnabled = true

        // The switch is only persisted once iOS has actually taken the request.
        // Leaving it on after a rejected schedule would promise a digest that
        // never arrives, with nothing on screen to say so.
        guard await refreshDailyDigest() else {
            notificationsEnabled = false
            presentError(String(localized: .notificationScheduleFailed))
            return
        }

        saveNotificationsEnabled()
    }

    /// Publishes the current top stories to the widget's shared container.
    /// Cheap and idempotent — it no-ops when nothing changed.
    func refreshWidgetSnapshot() {
        WidgetSnapshotWriter.write(personalizedItems)
    }

    /// Re-arms the digest with the current top story. Called on every fresh feed
    /// so the body keeps up without a background run iOS may never grant — the
    /// notification already exists, a refresh only makes its text newer.
    @discardableResult
    func refreshDailyDigest() async -> Bool {
        guard notificationsEnabled else {
            return false
        }
        let body = personalizedItems.first?.title
            ?? String(localized: .notificationDailyDigestFallback)
        return await notificationScheduler.scheduleDailyDigest(body: body)
    }

    /// Reconciles the stored setting with the system's answer at launch. A user
    /// who revoked permission outside the app would otherwise keep a switch
    /// that is on and a digest that never arrives.
    func syncNotificationAuthorization() async {
        guard notificationsEnabled else {
            return
        }
        guard await notificationScheduler.authorization() == .granted else {
            notificationsEnabled = false
            notificationsDeniedBySystem = true
            notificationScheduler.cancelDailyDigest()
            saveNotificationsEnabled()
            return
        }
        await refreshDailyDigest()
    }

    func processPendingSharedItems() {
        let defaults = UserDefaults(suiteName: "group.keen-onit.DeveloperNews") ?? .standard
        guard let pending = defaults.array(forKey: "pendingSharedItems") as? [[String: String]],
              !pending.isEmpty
        else { return }

        var consumedKeys: Set<String> = []

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
            consumedKeys.insert(entry["id"] ?? urlString)
        }

        // Drops only what was consumed: the extension is a separate process and
        // can append between the read above and this write.
        // ponytail: still a read-modify-write, so a simultaneous append can be
        // lost. NSFileCoordinator over a shared-container file if that matters.
        let remaining = (defaults.array(forKey: "pendingSharedItems") as? [[String: String]] ?? [])
            .filter { entry in
                guard let urlString = entry["url"] else {
                    return false
                }
                return !consumedKeys.contains(entry["id"] ?? urlString)
            }
        if remaining.isEmpty {
            defaults.removeObject(forKey: "pendingSharedItems")
        }
        else {
            defaults.set(remaining, forKey: "pendingSharedItems")
        }
    }

    private func loadPersistedState() {
        let state = persistenceStore.load()
        selectedTopics = state.selectedTopics
        savedItemsStore.seedInitialState(
            snapshots: state.savedItemSnapshots,
            timestamps: state.savedItemTimestampsByURL,
            sortOrder: state.savedSortOrder)
        notificationsEnabled = state.notificationsEnabled
        sourceCategoryStore.seedInitialState(
            disabledSourceCategories: state.disabledSourceCategories)
        blockedUserIds = state.blockedUserIds
        offlineArticleStore.seedInitialState(state.offlineArticles)
        readTracker.seedInitialState(
            readItemURLs: state.readItemURLs,
            readPostIds: state.readPostIds,
            readHistory: state.readHistory)
        translator.targetLanguageCode = state.translationLanguage
        hasSeenIntro = state.hasSeenIntro
        topStoryDismissedAt = state.topStoryDismissedAt
        feedStore.lastUpdatedAt = state.lastUpdatedAt
        feedStore.setInitialItems(state.allItems)
    }

    // MARK: - Persistence delegates

    // Serializes persistence writes through a task chain so they apply in call
    // order (no reordering), while the actor still encodes off the main actor.
    private func enqueuePersistence(
        _ write: @escaping @Sendable (PersistenceStore) async -> Void,
    ) {
        let store = persistenceStore
        let previous = persistenceChain
        persistenceChain = Task {
            await previous.value
            await write(store)
        }
    }

    private func saveTopics() {
        let topics = selectedTopics
        enqueuePersistence { store in
            await store.saveTopics(topics)
        }
    }

    private func saveSavedItems(
        snapshots: [URL: ContentItem],
        timestamps: [URL: Date],
    ) {
        enqueuePersistence { store in
            await store.saveSavedItems(
                snapshots: snapshots,
                timestamps: timestamps)
        }
    }

    private func saveSortOrder(_ order: SavedSortOrder) {
        enqueuePersistence { store in
            await store.saveSortOrder(order)
        }
    }

    private func saveNotificationsEnabled() {
        let isEnabled = notificationsEnabled
        enqueuePersistence { store in
            await store.saveNotificationsEnabled(isEnabled)
        }
    }

    private func saveDisabledSourceCategories(_ categories: Set<SourceCategory>) {
        enqueuePersistence { store in
            await store.saveDisabledSourceCategories(categories)
        }
    }

    private func saveBlockedUsers() {
        let userIds = blockedUserIds
        enqueuePersistence { store in
            await store.saveBlockedUsers(userIds)
        }
    }

    private func saveOfflineArticles(_ articles: [OfflineArticle]) {
        enqueuePersistence { store in
            await store.saveOfflineArticles(articles)
        }
    }

    private func saveReadHistory(_ history: [ReadRecord]) {
        enqueuePersistence { store in
            await store.saveReadHistory(history)
        }
    }

    private func saveReadItems(
        readItemURLs: Set<String>,
        readPostIds: Set<String>,
    ) {
        enqueuePersistence { store in
            await store.saveReadItems(
                readItemURLs: readItemURLs,
                readPostIds: readPostIds)
        }
    }

    private func saveTranslationLanguage() {
        let code = translator.targetLanguageCode
        enqueuePersistence { store in
            await store.saveTranslationLanguage(code)
        }
    }

    private func saveLastUpdatedAt(_ date: Date?) {
        enqueuePersistence { store in
            await store.saveLastUpdatedAt(date)
        }
    }

    private func saveHasSeenIntro() {
        let value = hasSeenIntro
        enqueuePersistence { store in
            await store.saveHasSeenIntro(value)
        }
    }

    private func saveTopStoryDismissedAt() {
        let date = topStoryDismissedAt
        enqueuePersistence { store in
            await store.saveTopStoryDismissedAt(date)
        }
    }

    private func saveAllItems(_ items: [ContentItem]) {
        enqueuePersistence { store in
            await store.saveAllItems(items)
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
