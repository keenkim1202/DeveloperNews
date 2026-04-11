import Foundation
import Observation

@Observable
final class AppState {
    var selectedTopics: Set<Topic> = []
    var savedItemIDs: Set<ContentItem.ID> = []
    let allItems = SampleData.items

    var isOnboardingComplete: Bool {
        !selectedTopics.isEmpty
    }

    var personalizedItems: [ContentItem] {
        let filteredItems: [ContentItem]
        if selectedTopics.isEmpty {
            filteredItems = allItems
        } else {
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

    func toggleTopic(_ topic: Topic) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        } else {
            selectedTopics.insert(topic)
        }
    }

    func toggleSaved(itemID: ContentItem.ID) {
        if savedItemIDs.contains(itemID) {
            savedItemIDs.remove(itemID)
        } else {
            savedItemIDs.insert(itemID)
        }
    }

    func resetTopics() {
        selectedTopics.removeAll()
    }
}
