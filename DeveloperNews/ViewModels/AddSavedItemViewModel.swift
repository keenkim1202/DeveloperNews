import Foundation
import Observation

@Observable
@MainActor
final class AddSavedItemViewModel {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func saveItem(
        title: String,
        description: String,
        link: String,
        selectedTopics: Set<Topic>,
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let itemURL: URL
        if let parsed = URL(string: trimmedLink), !trimmedLink.isEmpty {
            itemURL = parsed
        }
        else if let synthetic = URL(string: "devnews://saved/\(UUID().uuidString)") {
            itemURL = synthetic
        }
        else {
            return
        }

        let item = ContentItem(
            id: UUID(),
            kind: .article,
            title: trimmedTitle,
            summary: trimmedDescription,
            sourceName: appState.profileService.displayName.isEmpty
                ? String(localized: .saveMyBookmark)
                : appState.profileService.displayName,
            sourceCategory: .article,
            authorName: nil,
            url: itemURL,
            publishedAt: .now,
            topics: Topic.allCases.filter { selectedTopics.contains($0) },
            trendScore: 0,
            isUserCreated: true)

        appState.addSavedItem(item)
    }
}
