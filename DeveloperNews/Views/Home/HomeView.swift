import SwiftUI

struct HomeView: View {
    let appState: AppState
    @State private var viewModel: HomeViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: HomeViewModel(appState: appState))
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
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search stories")
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
                    Text("Loading stories")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Fetching the latest developer stories for your selected topics...")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if let errorMessage = viewModel.errorMessage, !viewModel.hasLoadedContent {
            ContentUnavailableView {
                Label("Could not load stories", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Text("Try again")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
        }
        else if viewModel.personalizedItems.isEmpty {
            ContentUnavailableView(
                "No stories for current topics",
                systemImage: "tray",
                description: Text("Try choosing a few more topics or refresh again in a moment."))
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
}

struct HomeTopicFocusBar: View {
    let selectedTopics: Set<Topic>
    let focusedTopic: Topic?
    let onClearFocus: () -> Void
    let onToggleFocus: (Topic) -> Void

    private var orderedTopics: [Topic] {
        Topic.allCases.filter { selectedTopics.contains($0) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FocusChip(
                    title: "focus.all",
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
