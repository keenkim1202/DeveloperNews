import Foundation
import Observation

@Observable
@MainActor
final class TopicSelectionViewModel {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var selectedTopics: Set<Topic> {
        appState.selectedTopics
    }
    var canSelectMore: Bool {
        appState.canSelectMoreTopics
    }
    var maxSelectedTopics: Int {
        AppState.maxSelectedTopics
    }
    var selectedCount: Int {
        appState.selectedTopics.count
    }

    func toggleTopic(_ topic: Topic) {
        appState.toggleTopic(topic)
    }
}
