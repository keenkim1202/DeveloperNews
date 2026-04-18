import SwiftUI

struct AddSavedItemView: View {
    let appState: AppState

    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var selectedTopics: Set<Topic> = []

    var body: some View {
        DraftEditorScreen(
            navigationTitle: .saveAddItem,
            saveTitle: "Save",
            title: $title,
            description: $description,
            link: $link,
            selectedTopics: $selectedTopics
        ) { _, _, _, _ in
            saveItem()
        }
    }

    private func saveItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let itemURL: URL
        if let parsed = URL(string: trimmedLink), !trimmedLink.isEmpty {
            itemURL = parsed
        }
        else {
            itemURL = URL(string: "devnews://saved/\(UUID().uuidString)")!
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

