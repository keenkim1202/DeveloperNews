import SwiftUI

struct SavedView: View {
    let appState: AppState
    @State private var viewModel: SavedViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: SavedViewModel(appState: appState))
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
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search saved stories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: openAddItem) {
                            Image(systemName: "plus")
                        }

                        if !viewModel.savedItems.isEmpty {
                            Menu {
                                Picker("Sort", selection: Binding(
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
                Label("No saved stories yet", systemImage: "bookmark")
            } description: {
                Text("Open a story you want to come back to and tap save. It will show up here.")
            } actions: {
                Button(action: goToHome) {
                    Text("Browse trending")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        else if !viewModel.hasAnyMatches {
            if viewModel.searchQuery.isEmpty {
                ContentUnavailableView(
                    "No saved stories in selected topics",
                    systemImage: "tray",
                    description: Text("Tap All to clear the topic filter or pick different topics above."))
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
    let availableTopics: [Topic]
    let selectedFilters: Binding<Set<Topic>>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FocusChip(
                    title: "focus.all",
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
