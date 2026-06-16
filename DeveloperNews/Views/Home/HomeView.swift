import SwiftUI

struct HomeView: View {
    private let appState: AppState

    @Bindable private var viewModel: HomeViewModel
    @Bindable private var navigation: Navigation

    init(
        appState: AppState,
        viewModel: HomeViewModel,
        navigation: Navigation,
    ) {
        self.appState = appState
        self.viewModel = viewModel
        self.navigation = navigation
    }

    var body: some View {
        NavigationStack(path: $navigation.home) {
            VStack(spacing: 0) {
                if viewModel.selectedTopics.count > 1 {
                    HomeTopicFocusBar(
                        selectedTopics: viewModel.selectedTopics,
                        focusedTopic: viewModel.focusedTopic,
                        onClearFocus: { viewModel.focusedTopic = nil },
                        onToggleFocus: { viewModel.toggleFocusedTopic($0) })
                }
                feedContent
            }
            .navigationTitle(.trending)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search stories")
            .refreshable(action: reload)
            .navigationDestination(for: HomeTabDestination.self, destination: destination)
        }
    }

    @ViewBuilder
    private func destination(_ dest: HomeTabDestination) -> some View {
        switch dest {
        case let .articleDetail(url):
            if let item = appState.resolveItem(url: url) {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .bookmarkDetail(url):
            if let item = appState.resolveItem(url: url) {
                BookmarkDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .communityPostDetail(postId):
            if let post = appState.communityService.post(id: postId) {
                CommunityPostDetailView(appState: appState, post: post)
            }
            else {
                UnavailableDestinationView(reason: .postDeleted)
            }
        case let .userProfile(author):
            UserProfileView(
                appState: appState,
                authorId: author.id,
                authorName: author.name,
                authorEmoji: author.emoji)
        }
    }

    private func destinationFor(_ item: ContentItem) -> HomeTabDestination {
        HomeTabDestination.forFeedItem(item, communityService: appState.communityService)
    }

    private func followingPost(for item: ContentItem) -> CommunityPost? {
        guard item.sourceCategory == .following,
              let postId = item.url.pathComponents.last
        else { return nil }
        return appState.communityService.posts.first { $0.id == postId }
    }

    private func navigateToProfile(_ author: AuthorInfo) {
        navigation(.home(.userProfile(author)))
    }

    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading && !viewModel.hasLoadedContent {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.accentColor)
                VStack(spacing: 4) {
                    Text(.loadingStories)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(.fetchingTheLatestDeveloperStoriesForYourSelectedTopics)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if let errorMessage = viewModel.errorMessage,
                !viewModel.hasLoadedContent {
            ContentUnavailableView {
                Label(.couldNotLoadStories, systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button(action: reloadContent) {
                    Text(.tryAgain)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
        }
        else if viewModel.personalizedItems.isEmpty {
            ContentUnavailableView(
                .noStoriesForCurrentTopics,
                systemImage: "tray",
                description: Text(.tryChoosingAFewMoreTopicsOrRefreshAgainInAMoment))
        }
        else {
            FeedSectionListView(
                translator: appState.translator,
                lastUpdatedAt: appState.lastUpdatedAt,
                isRead: { appState.isRead($0) },
                followingPost: followingPost(for:),
                authorEmoji: { appState.communityService.authorEmoji(for: $0) },
                articleItems: viewModel.articlesExcludingTopStory,
                discussionItems: viewModel.discussionsExcludingTopStory,
                destinationFor: destinationFor,
                onAuthorTap: navigateToProfile,
                hasMore: viewModel.hasMorePages,
                onLoadMore: { viewModel.loadMore() },
                scrollToTopTrigger: viewModel.scrollToTopTrigger,
                topContent: viewModel.topItem.map { item in
                    AnyView(
                        HomeTopStoryCard(
                            translator: appState.translator,
                            item: item,
                            destination: destinationFor(item),
                            onHide: { appState.dismissTopStory() })
                            .padding(.horizontal, 2)
                            .padding(.vertical, 4))
                })
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.regular)
                }
            }
        }
    }

    private func reloadContent() {
        Task {
            await viewModel.reload()
        }
    }

    private func reload() async {
        await viewModel.reload()
    }
}

struct HomeTopicFocusBar: View {
    private let selectedTopics: Set<Topic>
    private let focusedTopic: Topic?
    private let onClearFocus: () -> Void
    private let onToggleFocus: (Topic) -> Void

    init(
        selectedTopics: Set<Topic>,
        focusedTopic: Topic?,
        onClearFocus: @escaping () -> Void,
        onToggleFocus: @escaping (Topic) -> Void,
    ) {
        self.selectedTopics = selectedTopics
        self.focusedTopic = focusedTopic
        self.onClearFocus = onClearFocus
        self.onToggleFocus = onToggleFocus
    }

    private var orderedTopics: [Topic] {
        Topic.allCases.filter {
            selectedTopics.contains($0)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FocusChip(
                    title: .focusAll,
                    systemImage: "square.grid.2x2",
                    isSelected: focusedTopic == nil) {
                    onClearFocus()
                }
                ForEach(orderedTopics) { topic in
                    FocusChip(
                        title: topic.title,
                        systemImage: topic.symbolName,
                        isSelected: focusedTopic == topic) {
                        onToggleFocus(topic)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }
}
