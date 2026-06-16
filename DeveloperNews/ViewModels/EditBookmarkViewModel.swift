import Foundation
import Observation

@Observable
@MainActor
final class EditBookmarkViewModel {
    private let appState: AppState
    private let item: ContentItem

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
    }

    func saveChanges(
        title: String,
        description: String,
        link: String,
        selectedTopics: Set<Topic>,
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let newURL: URL
        if let parsed = URL(string: trimmedLink), !trimmedLink.isEmpty {
            newURL = parsed
        }
        else if item.hasExternalLink,
                let synthetic = URL(string: "devnews://saved/\(item.id.uuidString)") {
            newURL = synthetic
        }
        else {
            newURL = item.url
        }

        let updated = ContentItem(
            id: item.id,
            kind: item.kind,
            title: trimmedTitle,
            summary: trimmedDescription,
            sourceName: item.sourceName,
            sourceCategory: item.sourceCategory,
            authorName: item.authorName,
            url: newURL,
            publishedAt: item.publishedAt,
            topics: Topic.allCases.filter { selectedTopics.contains($0) },
            trendScore: item.trendScore,
            isUserCreated: true,
            updatedAt: .now)

        if newURL != item.url {
            appState.removeSavedItem(at: item.url)
            appState.addSavedItem(updated)
        }
        else {
            appState.updateSavedItem(updated)
        }
    }
}
