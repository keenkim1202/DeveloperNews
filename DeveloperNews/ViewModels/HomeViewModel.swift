import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private let appState: AppState

    var searchQuery = ""

    // In-app engagement counts keyed by item.url.absoluteString, matching the
    // detail screen's hashing so the same Firestore document is referenced.
    private(set) var storyEngagements: [String: StoryEngagement] = [:]

    init(appState: AppState) {
        self.appState = appState
    }

    var isLoading: Bool {
        appState.isLoading
    }
    var hasLoadedContent: Bool {
        appState.hasLoadedContent
    }
    var errorMessage: String? {
        appState.errorMessage
    }
    var personalizedItems: [ContentItem] {
        appState.personalizedItems
    }
    var selectedTopics: Set<Topic> {
        appState.selectedTopics
    }
    var hasMorePages: Bool {
        appState.hasMorePages
    }
    var scrollToTopTrigger: Int {
        appState.homeScrollToTopTrigger
    }

    var focusedTopic: Topic? {
        get {
            appState.focusedTopic
        }
        set {
            appState.focusedTopic = newValue
        }
    }

    var shouldShowTopStory: Bool {
        guard !appState.isTopStoryHidden else { return false }
        guard !personalizedItems.isEmpty else { return false }
        return !isLoading || hasLoadedContent
    }

    var topItem: ContentItem? {
        shouldShowTopStory && searchQuery.isEmpty ? personalizedItems.first : nil
    }

    var filteredArticleItems: [ContentItem] {
        searchFiltered(appState.pagedArticleItems)
    }

    var filteredDiscussionItems: [ContentItem] {
        searchFiltered(appState.pagedDiscussionItems)
    }

    var articlesExcludingTopStory: [ContentItem] {
        guard let top = topItem else { return filteredArticleItems }
        return filteredArticleItems.filter { $0.id != top.id }
    }

    var discussionsExcludingTopStory: [ContentItem] {
        guard let top = topItem else { return filteredDiscussionItems }
        return filteredDiscussionItems.filter { $0.id != top.id }
    }

    func reload() async {
        await appState.reload()
        await loadEngagements()
    }

    func loadMore() {
        appState.loadMore()
        Task {
            await loadEngagements()
        }
    }

    // Read-only enrichment: fetch in-app counts for the currently displayed
    // items and merge them in. Never blocks the feed; the service caps the batch
    // at 30 URLs, so items beyond that simply show no in-app counts.
    func loadEngagements() async {
        var displayed = articlesExcludingTopStory + discussionsExcludingTopStory
        if let top = topItem {
            displayed.insert(top, at: 0)
        }

        var seen = Set<String>()
        var urls: [String] = []
        for item in displayed {
            let key = item.url.absoluteString
            if seen.insert(key).inserted {
                urls.append(key)
            }
        }
        guard !urls.isEmpty else { return }

        let fetched = await appState.storyEngagementService.fetchEngagements(storyURLs: urls)
        storyEngagements.merge(fetched) { _, new in
            new
        }
    }

    // Home always renders this app's metrics, so an item without a fetched
    // document falls back to a zero-valued engagement. The summary view hides
    // itself when every count is zero, so blank items show nothing.
    func engagement(for item: ContentItem) -> StoryEngagement? {
        let key = item.url.absoluteString
        if let fetched = storyEngagements[key] {
            return fetched
        }
        return StoryEngagement(
            id: StoryEngagement.documentId(for: key),
            storyURL: key,
            likeCount: 0,
            likedBy: [],
            commentCount: 0,
            viewCount: 0)
    }

    func toggleFocusedTopic(_ topic: Topic) {
        appState.toggleFocusedTopic(topic)
    }

    var lastUpdatedAt: Date? {
        appState.lastUpdatedAt
    }

    var translator: any Translating {
        appState.translator
    }

    func isRead(_ item: ContentItem) -> Bool {
        appState.isRead(item)
    }

    func authorEmoji(for authorId: String) -> String? {
        appState.communityService.authorEmoji(for: authorId)
    }

    /// The community post a `.following` feed item stands for, if it is still loaded.
    func followingPost(for item: ContentItem) -> CommunityPost? {
        guard item.sourceCategory == .following,
              let postId = item.url.pathComponents.last
        else {
            return nil
        }
        return appState.communityService.post(id: postId)
    }

    func destination(for item: ContentItem) -> HomeTabDestination {
        HomeTabDestination.forFeedItem(item, communityService: appState.communityService)
    }

    func dismissTopStory() {
        appState.dismissTopStory()
    }

    private func searchFiltered(_ items: [ContentItem]) -> [ContentItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        let needle = query.lowercased()
        return items.filter {
            $0.title.lowercased().contains(needle) ||
            $0.summary.lowercased().contains(needle) ||
            $0.sourceName.lowercased().contains(needle)
        }
    }
}
