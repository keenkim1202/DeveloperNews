import SwiftUI

struct BookmarkDetailView: View {
    private let appState: AppState
    private let item: ContentItem
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
    }

    private var currentItem: ContentItem {
        appState.savedItemSnapshots[item.url] ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentItem.title)
                    .font(.title2.bold())
                HStack(spacing: 8) {
                    Text(currentItem.sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !currentItem.topics.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(currentItem.topics) { topic in
                            Label {
                                Text(topic.title)
                            } icon: {
                                Image(systemName: topic.symbolName)
                            }
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                    }
                }

                if !currentItem.summary.isEmpty {
                    Divider()
                    Text(currentItem.summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                if currentItem.hasExternalLink {
                    Divider()

                    NavigationLink {
                        ArticleDetailView(appState: appState, item: currentItem)
                    } label: {
                        HStack {
                            Label(.bookmarkOpenLink, systemImage: "safari")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(.bookmarkCreatedAt)
                        Text(currentItem.publishedAt, style: .date)
                        Text(currentItem.publishedAt, style: .time)
                    }
                    if let updatedAt = currentItem.updatedAt {
                        HStack(spacing: 4) {
                            Text(.bookmarkUpdatedAt)
                            Text(updatedAt, style: .date)
                            Text(updatedAt, style: .time)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                Button(
                    .bookmarkDelete,
                    role: .destructive,
                    action: confirmDelete)
                    .font(.footnote)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: onAppear)
        .dialog(
            .bookmarkDeleteConfirm,
            isPresented: $showDeleteConfirm,
            buttons: bookmarkDeleteConfirmDialogView)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openEdit) {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditBookmarkView(appState: appState, item: currentItem)
        }
    }

    private var bookmarkDeleteConfirmDialogView: some View {
        Button(
            "Delete",
            role: .destructive,
            action: deleteBookmark)
    }

    private func onAppear() {
        appState.markAsRead(currentItem)
    }

    private func confirmDelete() {
        showDeleteConfirm = true
    }

    private func deleteBookmark() {
        appState.removeSavedItem(at: currentItem.url)
        dismiss()
    }

    private func openEdit() {
        showEdit = true
    }
}


struct EditBookmarkView: View {
    private let appState: AppState
    private let item: ContentItem

    @State private var title: String
    @State private var description: String
    @State private var link: String
    @State private var selectedTopics: Set<Topic>

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
        _title = State(initialValue: item.title)
        _description = State(initialValue: item.summary)
        _link = State(initialValue: item.hasExternalLink ? item.url.absoluteString : "")
        _selectedTopics = State(initialValue: Set(item.topics))
    }

    var body: some View {
        DraftEditorScreen(
            navigationTitle: .bookmarkEdit,
            saveTitle: "Save",
            title: $title,
            description: $description,
            link: $link,
            selectedTopics: $selectedTopics
        ) { _, _, _, _ in
            saveChanges()
        }
    }

    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let newURL: URL
        if let parsed = URL(string: trimmedLink), !trimmedLink.isEmpty {
            newURL = parsed
        }
        else if item.hasExternalLink {
            newURL = URL(string: "devnews://saved/\(item.id.uuidString)")!
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

