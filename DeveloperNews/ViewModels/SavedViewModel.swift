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

    /// The community post a `.following` saved item stands for, if it is still loaded.
    func followingPost(for item: ContentItem) -> CommunityPost? {
        guard item.sourceCategory == .following,
              let postId = item.url.pathComponents.last
        else {
            return nil
        }
        return appState.communityService.post(id: postId)
    }

    func destination(for item: ContentItem) -> SavedTabDestination {
        SavedTabDestination.forFeedItem(item, communityService: appState.communityService)
    }

    var savedItems: [ContentItem] {
        appState.savedItems
    }
    var savedSortOrder: SavedSortOrder {
        appState.savedSortOrder
    }
    var scrollToTopTrigger: Int {
        appState.savedScrollToTopTrigger
    }

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
        // Captured body text is checked last: it is the only field that is not
        // already in memory as a short string, and the cheap ones settle most
        // queries before it is reached.
        return items.filter {
            $0.title.lowercased().contains(needle) ||
            $0.summary.lowercased().contains(needle) ||
            $0.sourceName.lowercased().contains(needle) ||
            appState.offlineBodyContains(needle, url: $0.url)
        }
    }

    private func topicFiltered(_ items: [ContentItem]) -> [ContentItem] {
        guard !topicFilters.isEmpty else { return items }
        return items.filter { !topicFilters.isDisjoint(with: $0.topics) }
    }
}
