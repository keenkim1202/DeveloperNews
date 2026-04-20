import SwiftUI

struct HomeView: View {
    private let appState: AppState

    @Bindable private var viewModel: HomeViewModel

    init(
        appState: AppState,
        viewModel: HomeViewModel,
    ) {
        self.appState = appState
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
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
            .refreshable {
                await viewModel.reload()
            }
        }
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
                appState: appState,
                articleItems: viewModel.articlesExcludingTopStory,
                discussionItems: viewModel.discussionsExcludingTopStory,
                hasMore: viewModel.hasMorePages,
                onLoadMore: { viewModel.loadMore() },
                scrollToTopTrigger: viewModel.scrollToTopTrigger,
                topContent: viewModel.topItem.map { item in
                    AnyView(
                        HomeTopStoryCard(appState: appState, item: item)
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
        onToggleFocus: @escaping (Topic) -> Void
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
