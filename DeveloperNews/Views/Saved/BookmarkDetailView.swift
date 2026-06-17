import SwiftUI

struct BookmarkDetailView: View {
    private let appState: AppState
    @State private var viewModel: BookmarkDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        _viewModel = State(initialValue: BookmarkDetailViewModel(
            appState: appState,
            item: item))
    }

    private var currentItem: ContentItem {
        viewModel.currentItem
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
                            .font(.dsTag)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                DSColor.surface
                            }
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
                            Label(.bookmarkOpenLink, icon: .safari)
                            Spacer()
                            Image(.chevronForward)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background {
                            DSColor.surface
                        }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openEdit) {
                    Image(.edit)
                }
            }
        }
        .onAppear(perform: onAppear)
        .dialog(
            .bookmarkDeleteConfirm,
            isPresented: $showDeleteConfirm,
            buttons: bookmarkDeleteConfirmDialogView)
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
        viewModel.markCurrentAsRead()
    }

    private func confirmDelete() {
        showDeleteConfirm = true
    }

    private func deleteBookmark() {
        viewModel.deleteBookmark()
        dismiss()
    }

    private func openEdit() {
        showEdit = true
    }
}


struct EditBookmarkView: View {
    @State private var viewModel: EditBookmarkViewModel

    @State private var title: String
    @State private var description: String
    @State private var link: String
    @State private var selectedTopics: Set<Topic>

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        _viewModel = State(initialValue: EditBookmarkViewModel(
            appState: appState,
            item: item))
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
        viewModel.saveChanges(
            title: title,
            description: description,
            link: link,
            selectedTopics: selectedTopics)
    }
}

