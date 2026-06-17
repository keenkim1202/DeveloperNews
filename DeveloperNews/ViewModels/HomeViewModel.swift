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

    func engagement(for item: ContentItem) -> StoryEngagement? {
        storyEngagements[item.url.absoluteString]
    }

    func toggleFocusedTopic(_ topic: Topic) {
        appState.toggleFocusedTopic(topic)
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
