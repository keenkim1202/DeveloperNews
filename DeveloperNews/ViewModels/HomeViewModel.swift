import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private let appState: AppState

    var searchQuery = ""

    init(appState: AppState) {
        self.appState = appState
    }

    var isLoading: Bool { appState.isLoading }
    var hasLoadedContent: Bool { appState.hasLoadedContent }
    var errorMessage: String? { appState.errorMessage }
    var personalizedItems: [ContentItem] { appState.personalizedItems }
    var selectedTopics: Set<Topic> { appState.selectedTopics }
    var hasMorePages: Bool { appState.hasMorePages }
    var scrollToTopTrigger: Int { appState.homeScrollToTopTrigger }

    var focusedTopic: Topic? {
        get { appState.focusedTopic }
        set { appState.focusedTopic = newValue }
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
    }

    func loadMore() {
        appState.loadMore()
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
