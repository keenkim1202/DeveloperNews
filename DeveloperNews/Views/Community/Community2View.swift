import SwiftUI

struct Community2View: View {
    private let appState: AppState

    @Bindable private var viewModel: Community2ViewModel
    @Bindable private var navigation: Navigation

    init(
        appState: AppState,
        viewModel: Community2ViewModel,
        navigation: Navigation,
    ) {
        self.appState = appState
        self.viewModel = viewModel
        self.navigation = navigation
    }

    var body: some View {
        NavigationStack(path: $navigation.community) {
            VStack(spacing: 0) {
                modePicker
                content
            }
            .navigationTitle(.community)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CommunityTabDestination.self, destination: destination)
            .onAppear(perform: onAppear)
        }
    }

    private var modePicker: some View {
        Picker(.community, selection: $viewModel.mode) {
            Text(.discoverTrending).tag(Community2ViewModel.Mode.trending)
            Text(.discoverRecent).tag(Community2ViewModel.Mode.recent)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.hasNoPosts {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if viewModel.hasNoPosts {
            ContentUnavailableView {
                Label(.discoverEmpty, icon: .community)
            } description: {
                Text(.discoverEmptyDescription)
            }
        }
        else {
            List {
                ForEach(viewModel.displayedPosts) { post in
                    FeedPostRow(
                        post: post,
                        currentUserId: appState.authService.userId,
                        onAuthorTap: { navigateToProfile(post) },
                        onLike: { toggleLike(post) })
                }
            }
            .listStyle(.plain)
            .refreshable(action: refresh)
        }
    }

    @ViewBuilder
    private func destination(_ dest: CommunityTabDestination) -> some View {
        switch dest {
        case let .userProfile(author):
            UserProfileView(
                appState: appState,
                authorId: author.id,
                authorName: author.name,
                authorEmoji: author.emoji)
        case let .storyDetail(story):
            if let item = story.contentItem {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .postDetail(postId):
            if let post = appState.communityService.post(id: postId) {
                CommunityPostDetailView(appState: appState, post: post)
            }
            else {
                UnavailableDestinationView(reason: .postDeleted)
            }
        case let .postLinkDetail(postId):
            if let post = appState.communityService.post(id: postId),
               let item = post.linkContentItem {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .followList(target):
            FollowListView(
                appState: appState,
                userId: target.userId,
                kind: target.kind)
        }
    }

    private func navigateToProfile(_ post: FeedPost) {
        navigation(.community(.userProfile(
            AuthorInfo(
                id: post.authorId,
                name: post.authorName,
                emoji: post.authorEmoji))))
    }

    private func toggleLike(_ post: FeedPost) {
        Task {
            await viewModel.toggleLike(post)
        }
    }

    private func onAppear() {
        guard !viewModel.hasLoaded else {
            return
        }
        Task {
            await viewModel.load()
        }
    }

    private func refresh() async {
        await viewModel.load()
    }
}
