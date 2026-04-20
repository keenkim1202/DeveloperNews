import SwiftUI

struct SavedView: View {
    private let appState: AppState

    @Bindable private var viewModel: SavedViewModel

    init(
        appState: AppState,
        viewModel: SavedViewModel,
    ) {
        self.appState = appState
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.savedItems.isEmpty && viewModel.availableTopics.count > 1 {
                    SavedTopicFilterBar(
                        availableTopics: viewModel.availableTopics,
                        selectedFilters: $viewModel.topicFilters)
                }

                content
            }
            .navigationTitle(.bookmarks)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: .searchSavedStories)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: openAddItem) {
                            Image(systemName: "plus")
                        }

                        if !viewModel.savedItems.isEmpty {
                            Menu {
                                Picker(.sort, selection: Binding(
                                    get: { viewModel.savedSortOrder },
                                    set: { viewModel.setSavedSortOrder($0) }
                                )) {
                                    ForEach(SavedSortOrder.allCases) { order in
                                        Text(order.title).tag(order)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddItem) {
                AddSavedItemView(appState: appState)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.savedItems.isEmpty {
            ContentUnavailableView {
                Label(.noSavedStoriesYet, systemImage: "bookmark")
            } description: {
                Text(.openAStoryYouWantToComeBackToAndTapSaveItWillShowUpHere)
            } actions: {
                Button(action: goToHome) {
                    Text(.browseTrending)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        else if !viewModel.hasAnyMatches {
            if viewModel.searchQuery.isEmpty {
                ContentUnavailableView(
                    .noSavedStoriesInSelectedTopics,
                    systemImage: "tray",
                    description: Text(.tapAllToClearTheTopicFilterOrPickDifferentTopicsAbove))
            }
            else {
                ContentUnavailableView.search(text: viewModel.searchQuery)
            }
        }
        else {
            FeedSectionListView(
                appState: appState,
                articleItems: viewModel.matchingArticleItems,
                discussionItems: viewModel.matchingDiscussionItems,
                showsSummary: false,
                scrollToTopTrigger: viewModel.scrollToTopTrigger)
        }
    }

    private func openAddItem() {
        viewModel.showAddItem = true
    }

    private func goToHome() {
        viewModel.navigateToHome()
    }
}


struct SavedTopicFilterBar: View {
    private let availableTopics: [Topic]
    private let selectedFilters: Binding<Set<Topic>>

    init(
        availableTopics: [Topic],
        selectedFilters: Binding<Set<Topic>>
    ) {
        self.availableTopics = availableTopics
        self.selectedFilters = selectedFilters
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FocusChip(
                    title: .focusAll,
                    systemImage: "square.grid.2x2",
                    isSelected: selectedFilters.wrappedValue.isEmpty) {
                    selectedFilters.wrappedValue.removeAll()
                }

                ForEach(availableTopics) { topic in
                    FocusChip(
                        title: topic.title,
                        systemImage: topic.symbolName,
                        isSelected: selectedFilters.wrappedValue.contains(topic)) {
                        if selectedFilters.wrappedValue.contains(topic) {
                            selectedFilters.wrappedValue.remove(topic)
                        }
                        else {
                            selectedFilters.wrappedValue.insert(topic)
                        }
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
