import Foundation
import Observation

@Observable
final class AppState {
    private enum StorageKey {
        static let selectedTopics = "selectedTopics"
        static let savedItemIDs = "savedItemIDs"
    }

    private let contentSourceClient: any ContentSourceClient

    var selectedTopics: Set<Topic> = []
    var savedItemIDs: Set<ContentItem.ID> = []
    var allItems: [ContentItem] = []
    var isLoading = false
    var errorMessage: String?

    init(contentSourceClient: (any ContentSourceClient)? = nil) {
        self.contentSourceClient = contentSourceClient ?? Self.defaultContentSourceClient()
        loadPersistedState()
    }

    var isOnboardingComplete: Bool {
        !selectedTopics.isEmpty
    }

    var personalizedItems: [ContentItem] {
        let filteredItems: [ContentItem]
        if selectedTopics.isEmpty {
            filteredItems = allItems
        }
        else {
            filteredItems = allItems.filter { item in
                !selectedTopics.isDisjoint(with: item.topics)
            }
        }

        return filteredItems.sorted {
            if $0.trendScore == $1.trendScore {
                return $0.publishedAt > $1.publishedAt
            }
            return $0.trendScore > $1.trendScore
        }
    }

    var savedItems: [ContentItem] {
        allItems.filter { savedItemIDs.contains($0.id) }
    }

    var hasLoadedContent: Bool {
        !allItems.isEmpty
    }

    func toggleTopic(_ topic: Topic) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        }
        else {
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

    func loadIfNeeded() async {
        guard !hasLoadedContent, !isLoading else {
            return
        }

        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil

        do {
            allItems = try await contentSourceClient.fetchItems()
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
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        let topicValues = selectedTopics.map(\.rawValue).sorted()
        let savedIDs = savedItemIDs.map(\.uuidString).sorted()

        defaults.set(topicValues, forKey: StorageKey.selectedTopics)
        defaults.set(savedIDs, forKey: StorageKey.savedItemIDs)
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
