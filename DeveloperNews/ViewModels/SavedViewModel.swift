import Foundation
import Observation

@Observable
@MainActor
final class SavedViewModel {
    private let appState: AppState

    var searchQuery = ""
    var topicFilters: Set<Topic> = []
    var showAddItem = false

    init(appState: AppState) {
        self.appState = appState
    }

    var savedItems: [ContentItem] { appState.savedItems }
    var savedSortOrder: SavedSortOrder { appState.savedSortOrder }
    var scrollToTopTrigger: Int { appState.savedScrollToTopTrigger }

    var availableTopics: [Topic] {
        let union = Set(savedItems.flatMap(\.topics))
        return Topic.allCases.filter { union.contains($0) }
    }

    var matchingArticleItems: [ContentItem] {
        applyFilters(to: appState.savedArticleItems)
    }

    var matchingDiscussionItems: [ContentItem] {
        applyFilters(to: appState.savedDiscussionItems)
    }

    var hasAnyMatches: Bool {
        !matchingArticleItems.isEmpty || !matchingDiscussionItems.isEmpty
    }

    func setSavedSortOrder(_ order: SavedSortOrder) {
        appState.setSavedSortOrder(order)
    }

    func navigateToHome() {
        appState.currentTab = .home
    }

    private func applyFilters(to items: [ContentItem]) -> [ContentItem] {
        let bySearch = searchFiltered(items)
        return topicFiltered(bySearch)
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

    private func topicFiltered(_ items: [ContentItem]) -> [ContentItem] {
        guard !topicFilters.isEmpty else { return items }
        return items.filter { !topicFilters.isDisjoint(with: $0.topics) }
    }
}
