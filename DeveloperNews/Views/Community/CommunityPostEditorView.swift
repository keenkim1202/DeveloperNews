import SwiftUI

struct CommunityPostEditorView: View {
    @State private var viewModel: CommunityPostEditorViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var link: String
    @State private var selectedTopics: Set<Topic>

    init(
        appState: AppState,
        existingPost: CommunityPost? = nil,
    ) {
        _viewModel = State(initialValue: CommunityPostEditorViewModel(
            appState: appState,
            existingPost: existingPost))
        _title = State(initialValue: existingPost?.title ?? "")
        _description = State(initialValue: existingPost?.description ?? "")
        _link = State(initialValue: existingPost?.link ?? "")
        _selectedTopics = State(initialValue: Set(existingPost?.topics ?? []))
    }

    var body: some View {
        DraftEditorScreen(
            navigationTitle: viewModel.isEditing ? .communityEditPost : .communityNewPost,
            saveTitle: viewModel.isEditing ? .communitySavePost : .communityPost,
            title: $title,
            description: $description,
            link: $link,
            selectedTopics: $selectedTopics
        ) { _, _, _, _ in
            savePost()
        }
    }

    private func savePost() {
        viewModel.savePost(
            title: title,
            description: description,
            link: link,
            selectedTopics: selectedTopics)
    }
}


struct CreatePostView: View {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        CommunityPostEditorView(appState: appState)
    }
}


struct EditCommunityPostView: View {
    private let appState: AppState
    private let post: CommunityPost

    init(
        appState: AppState,
        post: CommunityPost,
    ) {
        self.appState = appState
        self.post = post
    }

    var body: some View {
        CommunityPostEditorView(
            appState: appState,
            existingPost: post)
    }
}

