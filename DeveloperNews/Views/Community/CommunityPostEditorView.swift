import SwiftUI

struct CommunityPostEditorView: View {
    private let appState: AppState
    private let existingPost: CommunityPost?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var link: String
    @State private var selectedTopics: Set<Topic>

    init(
        appState: AppState,
        existingPost: CommunityPost? = nil,
    ) {
        self.appState = appState
        self.existingPost = existingPost
        _title = State(initialValue: existingPost?.title ?? "")
        _description = State(initialValue: existingPost?.description ?? "")
        _link = State(initialValue: existingPost?.link ?? "")
        _selectedTopics = State(initialValue: Set(existingPost?.topics ?? []))
    }

    private var isEditing: Bool {
        existingPost != nil
    }

    var body: some View {
        DraftEditorScreen(
            navigationTitle: isEditing ? .communityEditPost : .communityNewPost,
            saveTitle: isEditing ? .communitySavePost : .communityPost,
            title: $title,
            description: $description,
            link: $link,
            selectedTopics: $selectedTopics
        ) { _, _, _, _ in
            savePost()
        }
    }

    private func savePost() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let topics = Topic.allCases.filter { selectedTopics.contains($0) }

        if let existingPost {
            guard let userId = appState.authService.userId else { return }
            Task {
                await appState.communityService.updatePost(
                    existingPost,
                    title: trimmedTitle,
                    description: trimmedDescription,
                    link: trimmedLink.isEmpty ? nil : trimmedLink,
                    topics: topics,
                    editorId: userId)
            }
        }
        else {
            guard let user = appState.authService.user else { return }
            Task {
                await appState.communityService.createPost(
                    title: trimmedTitle,
                    description: trimmedDescription,
                    link: trimmedLink.isEmpty ? nil : trimmedLink,
                    topics: topics,
                    author: user,
                    authorDisplayName: appState.profileService.displayName)
            }
        }
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

    init(appState: AppState, post: CommunityPost) {
        self.appState = appState
        self.post = post
    }

    var body: some View {
        CommunityPostEditorView(
            appState: appState,
            existingPost: post)
    }
}

