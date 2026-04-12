import AuthenticationServices
import SwiftUI
import Translation
import WebKit

private struct LimitedTextField: View {
    var text: Binding<String>
    let limit: Int
    let prompt: LocalizedStringResource

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextField(prompt, text: text)
                .onChange(of: text.wrappedValue) { _, new in
                    if new.count > limit { text.wrappedValue = String(new.prefix(limit)) }
                }
            Text("\(text.wrappedValue.count) / \(limit)")
                .font(.caption2)
                .foregroundStyle(text.wrappedValue.count >= limit ? Color.red : Color.secondary)
        }
    }
}

private struct LimitedTextEditor: View {
    var text: Binding<String>
    let limit: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextEditor(text: text)
                .frame(minHeight: 100)
                .onChange(of: text.wrappedValue) { _, new in
                    if new.count > limit { text.wrappedValue = String(new.prefix(limit)) }
                }
            Text("\(text.wrappedValue.count) / \(limit)")
                .font(.caption2)
                .foregroundStyle(text.wrappedValue.count >= limit ? Color.red : Color.secondary)
        }
    }
}

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter
}()

@MainActor
struct ContentView: View {
    @State private var appState = AppState()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    private static let staleThreshold: TimeInterval = 15 * 60

    var body: some View {
        Group {
            if showSplash {
                SplashView(appState: appState) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
            }
            else if appState.isOnboardingComplete {
                MainTabView(appState: appState)
                    .task {
                        await appState.loadIfNeeded()
                    }
            }
            else {
                TopicSelectionView(appState: appState)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, appState.isOnboardingComplete else {
                return
            }
            Task {
                await appState.refreshIfStale(maxAge: Self.staleThreshold)
            }
        }
        .onChange(of: appState.authService.isSignedIn) { _, signedIn in
            if signedIn, let user = appState.authService.user {
                appState.profileService.startListening(for: user)
                Task {
                    await appState.profileService.createProfileIfNeeded(for: user)
                }
            }
            else {
                appState.profileService.stopListening()
            }
        }
        .onAppear {
            if let user = appState.authService.user {
                appState.profileService.startListening(for: user)
            }
            appState.communityService.startListening()
        }
    }
}

private struct SplashView: View {
    let appState: AppState
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image("LaunchIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

            Text("DeveloperNews")
                .font(.keenPixelTitle)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            Task {
                await appState.loadIfNeeded()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete()
            }
        }
    }
}

#Preview {
    ContentView()
}

private struct TopicSelectionView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pick your developer interests")
                            .font(.largeTitle.bold())
                        Text("Start with a few topics. We will use them to shape your first trending feed.")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Text("Selected")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(appState.selectedTopics.count) / \(AppState.maxSelectedTopics)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(appState.selectedTopics.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Topic.allCases) { topic in
                            let isSelected = appState.selectedTopics.contains(topic)
                            let isDisabled = !isSelected && !appState.canSelectMoreTopics

                            Button {
                                appState.toggleTopic(topic)
                            } label: {
                                HStack {
                                    Image(systemName: topic.symbolName)
                                    Text(topic.title)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .padding(.horizontal, 12)
                                .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .opacity(isDisabled ? 0.4 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDisabled)
                        }
                    }

                    Text("Pick 1 to \(AppState.maxSelectedTopics) topics to continue.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("DeveloperNews")
        }
    }
}

private struct MainTabView: View {
    let appState: AppState

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { appState.currentTab },
            set: { newValue in
                appState.notifyTabSelected(newValue)
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(appState: appState)
                .tabItem {
                    Label("Home", systemImage: "newspaper")
                }
                .tag(AppTab.home)

            CommunityView(appState: appState)
                .tabItem {
                    Label("Community", systemImage: "person.2")
                }
                .tag(AppTab.community)

            SavedView(appState: appState)
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }
                .tag(AppTab.saved)

            SettingsView(appState: appState)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}

private struct HomeView: View {
    let appState: AppState

    var body: some View {
        let topItem = shouldShowTopStory ? appState.personalizedItems.first : nil

        NavigationStack {
            VStack(spacing: 0) {
                if appState.selectedTopics.count > 1 {
                    HomeTopicFocusBar(appState: appState)
                }

                if let topItem {
                    HomeTopStoryCard(appState: appState, item: topItem)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                feedContent(excluding: topItem)
            }
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await appState.reload()
            }
        }
    }

    private var shouldShowTopStory: Bool {
        guard !appState.isTopStoryHidden else { return false }
        guard !appState.personalizedItems.isEmpty else { return false }
        return !appState.isLoading || appState.hasLoadedContent
    }

    @ViewBuilder
    private func feedContent(excluding topItem: ContentItem?) -> some View {
        Group {
            if appState.isLoading && !appState.hasLoadedContent {
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
                else if let errorMessage = appState.errorMessage, !appState.hasLoadedContent {
                    ContentUnavailableView {
                        Label("Could not load stories", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button {
                            Task { await appState.reload() }
                        } label: {
                            Text("Try again")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.isLoading)
                    }
                }
                else if appState.personalizedItems.isEmpty {
                    ContentUnavailableView(
                        "No stories for current topics",
                        systemImage: "tray",
                        description: Text("Try choosing a few more topics or refresh again in a moment.")
                    )
                }
                else {
                    let articleItems = topItem.map { top in
                        appState.pagedArticleItems.filter { $0.id != top.id }
                    } ?? appState.pagedArticleItems
                    let discussionItems = topItem.map { top in
                        appState.pagedDiscussionItems.filter { $0.id != top.id }
                    } ?? appState.pagedDiscussionItems

                    FeedSectionListView(
                        appState: appState,
                        articleItems: articleItems,
                        discussionItems: discussionItems,
                        hasMore: appState.hasMorePages,
                        onLoadMore: { appState.loadMore() },
                        scrollToTopTrigger: appState.homeScrollToTopTrigger
                    )
                    .overlay {
                        if appState.isLoading {
                            ProgressView()
                                .controlSize(.regular)
                        }
                    }
                }
        }
    }
}

private struct HomeTopicFocusBar: View {
    let appState: AppState

    private var orderedTopics: [Topic] {
        Topic.allCases.filter { appState.selectedTopics.contains($0) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FocusChip(
                    title: "focus.all",
                    systemImage: "square.grid.2x2",
                    isSelected: appState.focusedTopic == nil
                ) {
                    appState.focusedTopic = nil
                }

                ForEach(orderedTopics) { topic in
                    FocusChip(
                        title: topic.title,
                        systemImage: topic.symbolName,
                        isSelected: appState.focusedTopic == topic
                    ) {
                        appState.toggleFocusedTopic(topic)
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

private struct FocusChip: View {
    let title: LocalizedStringResource
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SavedView: View {
    let appState: AppState
    @State private var searchQuery = ""
    @State private var topicFilters: Set<Topic> = []
    @State private var showAddItem = false

    private var availableTopics: [Topic] {
        let union = Set(appState.savedItems.flatMap(\.topics))
        return Topic.allCases.filter { union.contains($0) }
    }

    private var matchingArticleItems: [ContentItem] {
        applyFilters(to: appState.savedArticleItems)
    }

    private var matchingDiscussionItems: [ContentItem] {
        applyFilters(to: appState.savedDiscussionItems)
    }

    private var hasAnyMatches: Bool {
        !matchingArticleItems.isEmpty || !matchingDiscussionItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !appState.savedItems.isEmpty && availableTopics.count > 1 {
                    SavedTopicFilterBar(
                        availableTopics: availableTopics,
                        selectedFilters: $topicFilters
                    )
                }

                content
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search saved stories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus")
                        }

                        if !appState.savedItems.isEmpty {
                            Menu {
                                Picker("Sort", selection: Binding(
                                    get: { appState.savedSortOrder },
                                    set: { appState.setSavedSortOrder($0) }
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
            .sheet(isPresented: $showAddItem) {
                AddSavedItemView(appState: appState)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if appState.savedItems.isEmpty {
            ContentUnavailableView {
                Label("No saved stories yet", systemImage: "bookmark")
            } description: {
                Text("Open a story you want to come back to and tap save. It will show up here.")
            } actions: {
                Button {
                    appState.currentTab = .home
                } label: {
                    Text("Browse trending")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        else if !hasAnyMatches {
            if searchQuery.isEmpty {
                ContentUnavailableView(
                    "No saved stories in selected topics",
                    systemImage: "tray",
                    description: Text("Tap All to clear the topic filter or pick different topics above.")
                )
            }
            else {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
        else {
            FeedSectionListView(
                appState: appState,
                articleItems: matchingArticleItems,
                discussionItems: matchingDiscussionItems,
                showsSummary: false,
                scrollToTopTrigger: appState.savedScrollToTopTrigger
            )
        }
    }

    private func applyFilters(to items: [ContentItem]) -> [ContentItem] {
        let bySearch = searchFiltered(items)
        return topicFiltered(bySearch)
    }

    private func searchFiltered(_ items: [ContentItem]) -> [ContentItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return items
        }

        let needle = query.lowercased()
        return items.filter { item in
            item.title.lowercased().contains(needle)
                || item.summary.lowercased().contains(needle)
                || item.sourceName.lowercased().contains(needle)
        }
    }

    private func topicFiltered(_ items: [ContentItem]) -> [ContentItem] {
        guard !topicFilters.isEmpty else {
            return items
        }
        return items.filter { !topicFilters.isDisjoint(with: $0.topics) }
    }
}

private struct SavedTopicFilterBar: View {
    let availableTopics: [Topic]
    let selectedFilters: Binding<Set<Topic>>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FocusChip(
                    title: "focus.all",
                    systemImage: "square.grid.2x2",
                    isSelected: selectedFilters.wrappedValue.isEmpty
                ) {
                    selectedFilters.wrappedValue.removeAll()
                }

                ForEach(availableTopics) { topic in
                    FocusChip(
                        title: topic.title,
                        systemImage: topic.symbolName,
                        isSelected: selectedFilters.wrappedValue.contains(topic)
                    ) {
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

private struct FeedSectionListView: View {
    let appState: AppState
    let articleItems: [ContentItem]
    let discussionItems: [ContentItem]
    var showsSummary = true
    var hasMore: Bool = false
    var onLoadMore: (() -> Void)? = nil
    var scrollToTopTrigger: Int = 0

    private var firstAnchorID: ContentItem.ID? {
        articleItems.first?.id ?? discussionItems.first?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            list
                .onChange(of: scrollToTopTrigger) { _, _ in
                    guard let anchor = firstAnchorID else { return }
                    withAnimation {
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                }
        }
    }

    private var list: some View {
        List {
            if showsSummary {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(articleItems.count + discussionItems.count) stories across your selected topics")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let lastUpdatedAt = appState.lastUpdatedAt {
                            Text("Updated \(relativeDateFormatter.localizedString(for: lastUpdatedAt, relativeTo: .now))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))
                }
            }

            if !articleItems.isEmpty {
                Section {
                    ForEach(articleItems) { item in
                        FeedItemRow(appState: appState, item: item)
                    }
                }
            }

            if !discussionItems.isEmpty {
                Section("Discussions") {
                    ForEach(discussionItems) { item in
                        FeedItemRow(appState: appState, item: item)
                    }
                }
            }

            if hasMore, let onLoadMore {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onAppear {
                        onLoadMore()
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, showsSummary ? 0 : 8, for: .scrollContent)
    }
}

private struct HomeTopStoryCard: View {
    let appState: AppState
    let item: ContentItem

    private var translator: ContentTranslator { appState.translator }

    @State private var translationTrigger = 0
    @State private var showingTranslation = false

    private var displayTitle: String {
        showingTranslation ? translator.title(for: item) : item.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Top story", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.dismissTopStory()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Hide for a day")
                        Image(systemName: "xmark")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide top story for a day")
            }

            NavigationLink {
                if item.isUserCreated {
                    BookmarkDetailView(appState: appState, item: item)
                }
                else {
                    ArticleDetailView(appState: appState, item: item)
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    HomeTopStoryThumbnail(url: item.thumbnailURL)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 6) {
                            Text(item.sourceName)
                                .lineLimit(1)
                            Text("·")
                            Text(relativeDateFormatter.localizedString(for: item.publishedAt, relativeTo: .now))
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if translator.needsTranslation {
                Button {
                    if translator.isTranslated(item) {
                        showingTranslation.toggle()
                    }
                    else {
                        translationTrigger &+= 1
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "translate")
                        Text(showingTranslation ? "translation.showOriginal" : "translation.showTranslated")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(showingTranslation ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if let config = translator.makeConfiguration(), translationTrigger > 0 {
                Color.clear
                    .id(translationTrigger)
                    .translationTask(config) { session in
                        await translator.translateSingle(item, using: session)
                        showingTranslation = true
                    }
            }
        }
    }
}

private struct HomeTopStoryThumbnail: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        Color(.tertiarySystemFill)
                            .overlay { ProgressView().controlSize(.small) }
                    @unknown default:
                        placeholder
                    }
                }
            }
            else {
                placeholder
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        Color(.tertiarySystemFill)
            .overlay {
                Image(systemName: "newspaper")
                    .foregroundStyle(.secondary)
            }
    }
}

private struct FeedItemRow: View {
    let appState: AppState
    let item: ContentItem

    private var translator: ContentTranslator { appState.translator }

    @State private var translationTrigger = 0
    @State private var showingTranslation = false

    private var displayTitle: String {
        showingTranslation ? translator.title(for: item) : item.title
    }

    private var displaySummary: String {
        showingTranslation ? translator.summary(for: item) : item.summary
    }

    var body: some View {
        NavigationLink {
            if item.isUserCreated {
                BookmarkDetailView(appState: appState, item: item)
            }
            else {
                ArticleDetailView(appState: appState, item: item)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                FeedItemMetaView(item: item)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(displayTitle)
                            .font(.headline)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let thumbnailURL = item.thumbnailURL {
                            FeedItemThumbnailView(url: thumbnailURL)
                        }
                    }

                    Text(displaySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if !item.topics.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(item.topics) { topic in
                                Text(topic.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.leading, -8)
                    .scrollClipDisabled()
                }

                if translator.needsTranslation {
                    Button {
                        if translator.isTranslated(item) {
                            showingTranslation.toggle()
                        }
                        else {
                            translationTrigger &+= 1
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "translate")
                            Text(showingTranslation ? "translation.showOriginal" : "translation.showTranslated")
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(showingTranslation ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                }

                if let engagement = item.engagement {
                    EngagementSummaryView(engagement: engagement)
                }
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if let config = translator.makeConfiguration(), translationTrigger > 0 {
                Color.clear
                    .id(translationTrigger)
                    .translationTask(config) { session in
                        await translator.translateSingle(item, using: session)
                        showingTranslation = true
                    }
            }
        }
    }
}

private struct EngagementSummaryView: View {
    let engagement: EngagementMetrics

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                Text(formatted(engagement.reactionCount))
            }
            HStack(spacing: 2) {
                Image(systemName: "bubble.left")
                Text(formatted(engagement.commentCount))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func formatted(_ value: Int) -> String {
        if value >= 1000 {
            let thousands = Double(value) / 1000
            return String(format: "%.1fk", thousands)
        }
        return "\(value)"
    }
}

private struct ArticleWebView: UIViewRepresentable {
    let url: URL
    let isLoading: Binding<Bool>
    let loadError: Binding<String?>
    let progress: Binding<Double>
    let webViewRef: Binding<WKWebView?>
    let reloadTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        context.coordinator.observedWebView = webView
        DispatchQueue.main.async {
            self.webViewRef.wrappedValue = webView
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            context.coordinator.lastReloadTrigger = reloadTrigger
            webView.load(URLRequest(url: url))
        }
        else if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            webView.reload()
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        if let observed = coordinator.observedWebView {
            observed.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            coordinator.observedWebView = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ArticleWebView
        var loadedURL: URL?
        var lastReloadTrigger: Int
        weak var observedWebView: WKWebView?

        init(parent: ArticleWebView) {
            self.parent = parent
            self.lastReloadTrigger = parent.reloadTrigger
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            guard
                keyPath == #keyPath(WKWebView.estimatedProgress),
                let webView = object as? WKWebView
            else {
                return
            }
            let value = webView.estimatedProgress
            DispatchQueue.main.async {
                self.parent.progress.wrappedValue = value
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = true
                self.parent.loadError.wrappedValue = nil
                self.parent.progress.wrappedValue = 0
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.progress.wrappedValue = 1
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.loadError.wrappedValue = error.localizedDescription
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading.wrappedValue = false
                self.parent.loadError.wrappedValue = error.localizedDescription
            }
        }
    }
}

private struct FeedItemThumbnailView: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Color(.tertiarySystemFill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                Color(.tertiarySystemFill)
                    .overlay { ProgressView().controlSize(.small) }
            @unknown default:
                Color(.tertiarySystemFill)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct FeedItemMetaView: View {
    let item: ContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: item.kind.symbolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(item.sourceName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(relativeDateFormatter.localizedString(for: item.publishedAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }

            if let linkLabel = externalLinkLabel(for: item) {
                Text(linkLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

private func externalLinkLabel(for item: ContentItem) -> String? {
    guard let host = item.url.host else {
        return nil
    }

    let cleaned = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    let normalizedSource = item.sourceName.lowercased().replacingOccurrences(of: " ", with: "")

    if cleaned.lowercased().replacingOccurrences(of: ".", with: "").contains(normalizedSource) {
        return nil
    }

    return cleaned
}

private let appVersionString: String = {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "0.0"
    let build = info?["CFBundleVersion"] as? String ?? "0"
    return "\(version) (\(build))"
}()

// MARK: - Community

private struct CommunityView: View {
    let appState: AppState
    @State private var showCreatePost = false

    private var community: CommunityService { appState.communityService }
    private var currentUserId: String? { appState.authService.userId }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                content
                    .onChange(of: appState.communityScrollToTopTrigger) { _, _ in
                        guard let anchor = community.posts.first?.id else { return }
                        withAnimation {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                    }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appState.authService.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreatePost = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView(appState: appState)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if community.isLoading && community.posts.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if community.posts.isEmpty {
            ContentUnavailableView {
                Label("community.empty", systemImage: "person.2")
            } description: {
                Text("community.emptyDescription")
            }
        }
        else {
            List {
                ForEach(community.posts) { post in
                    NavigationLink {
                        CommunityPostDetailView(appState: appState, post: post)
                    } label: {
                        CommunityPostRow(appState: appState, post: post)
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                community.startListening()
            }
        }
    }
}

private struct CommunityPostRow: View {
    let appState: AppState
    let post: CommunityPost

    private var currentUserId: String? { appState.authService.userId }
    private var isLiked: Bool {
        guard let uid = currentUserId else { return false }
        return post.likedBy.contains(uid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(post.authorName)
                    .font(.caption.weight(.semibold))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(relativeDateFormatter.localizedString(for: post.createdAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(post.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if !post.description.isEmpty {
                Text(post.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !post.topics.isEmpty {
                HStack(spacing: 4) {
                    ForEach(post.topics) { topic in
                        Text(topic.title)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? .red : .secondary)
                Text("\(post.likeCount)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

private struct CommunityPostDetailView: View {
    let appState: AppState
    let post: CommunityPost
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var community: CommunityService { appState.communityService }
    private var currentUserId: String? { appState.authService.userId }
    private var isAuthor: Bool { currentUserId == post.authorId }
    private var isLiked: Bool {
        guard let uid = currentUserId else { return false }
        return post.likedBy.contains(uid)
    }

    private var currentPost: CommunityPost {
        community.posts.first { $0.id == post.id } ?? post
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentPost.title)
                    .font(.title2.bold())

                HStack(spacing: 8) {
                    Text(currentPost.authorName)
                        .font(.caption.weight(.semibold))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(currentPost.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !currentPost.topics.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(currentPost.topics) { topic in
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

                if !currentPost.description.isEmpty {
                    Divider()

                    Text(currentPost.description)
                        .font(.body)
                }

                if currentPost.hasLink, let url = currentPost.linkURL {
                    Divider()

                    let linkItem = ContentItem(
                        id: UUID(),
                        kind: .article,
                        title: currentPost.title,
                        summary: "",
                        sourceName: currentPost.authorName,
                        sourceCategory: .article,
                        authorName: currentPost.authorName,
                        url: url,
                        publishedAt: currentPost.createdAt,
                        topics: currentPost.topics,
                        trendScore: 0
                    )

                    NavigationLink {
                        ArticleDetailView(appState: appState, item: linkItem)
                    } label: {
                        HStack {
                            Label("bookmark.openLink", systemImage: "safari")
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

                HStack {
                    Button {
                        guard let uid = currentUserId else { return }
                        Task {
                            await community.toggleLike(currentPost, userId: uid)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? .red : .secondary)
                            Text("\(currentPost.likeCount)")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentUserId == nil)

                    Spacer()
                }

                if isAuthor {
                    Button("community.deletePost", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .font(.footnote)
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("community.deleteConfirm", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await community.deletePost(currentPost)
                    dismiss()
                }
            }
        }
    }
}

private struct CreatePostView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var selectedTopics: Set<Topic> = []

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLink = !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDescription = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && !selectedTopics.isEmpty && (hasLink || hasDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LimitedTextField(text: $title, limit: 100, prompt: "save.titlePlaceholder")

                    TextField("save.linkPlaceholder", text: $link)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("save.details")
                }

                Section {
                    LimitedTextEditor(text: $description, limit: 1000)
                } header: {
                    Text("save.description")
                }

                Section {
                    ForEach(Topic.allCases) { topic in
                        Button {
                            if selectedTopics.contains(topic) {
                                selectedTopics.remove(topic)
                            }
                            else {
                                selectedTopics.insert(topic)
                            }
                        } label: {
                            HStack {
                                Label {
                                    Text(topic.title)
                                } icon: {
                                    Image(systemName: topic.symbolName)
                                }
                                Spacer()
                                if selectedTopics.contains(topic) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("save.topic")
                }
            }
            .navigationTitle("community.newPost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("community.post") {
                        createPost()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func createPost() {
        guard let user = appState.authService.user else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await appState.communityService.createPost(
                title: trimmedTitle,
                description: trimmedDescription,
                link: trimmedLink.isEmpty ? nil : trimmedLink,
                topics: Topic.allCases.filter { selectedTopics.contains($0) },
                author: user,
                authorDisplayName: appState.profileService.displayName
            )
        }
    }
}

// MARK: - Saved

private struct AddSavedItemView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var selectedTopics: Set<Topic> = []

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLink = !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDescription = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && !selectedTopics.isEmpty && (hasLink || hasDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LimitedTextField(text: $title, limit: 100, prompt: "save.titlePlaceholder")

                    TextField("save.linkPlaceholder", text: $link)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("save.details")
                }

                Section {
                    LimitedTextEditor(text: $description, limit: 1000)
                } header: {
                    Text("save.description")
                }

                Section {
                    ForEach(Topic.allCases) { topic in
                        Button {
                            if selectedTopics.contains(topic) {
                                selectedTopics.remove(topic)
                            }
                            else {
                                selectedTopics.insert(topic)
                            }
                        } label: {
                            HStack {
                                Label {
                                    Text(topic.title)
                                } icon: {
                                    Image(systemName: topic.symbolName)
                                }
                                Spacer()
                                if selectedTopics.contains(topic) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("save.topic")
                }
            }
            .navigationTitle("save.addItem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func saveItem() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        let itemURL: URL
        if let parsed = URL(string: trimmedLink), !trimmedLink.isEmpty {
            itemURL = parsed
        }
        else {
            itemURL = URL(string: "devnews://saved/\(UUID().uuidString)")!
        }

        let item = ContentItem(
            id: UUID(),
            kind: .article,
            title: trimmedTitle,
            summary: trimmedDescription,
            sourceName: appState.profileService.displayName.isEmpty
                ? String(localized: "save.myBookmark")
                : appState.profileService.displayName,
            sourceCategory: .article,
            authorName: nil,
            url: itemURL,
            publishedAt: .now,
            topics: Topic.allCases.filter { selectedTopics.contains($0) },
            trendScore: 0,
            isUserCreated: true
        )

        appState.addSavedItem(item)
    }
}

private struct SettingsView: View {
    let appState: AppState

    @State private var showSignIn = false
    @State private var showEditName = false
    @State private var editingName = ""

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                settingsList
                    .onChange(of: appState.settingsScrollToTopTrigger) { _, _ in
                        withAnimation {
                            proxy.scrollTo("__settings_top__", anchor: .top)
                        }
                    }
            }
            .sheet(isPresented: $showSignIn) {
                SignInView(authService: appState.authService)
            }
            .alert("profile.editName", isPresented: $showEditName) {
                TextField("profile.namePlaceholder", text: $editingName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        await appState.profileService.updateDisplayName(trimmed)
                    }
                }
            } message: {
                Text("profile.editNameMessage")
            }
        }
    }

    private var settingsList: some View {
        List {
            accountSection
                .id("__settings_top__")

            Section("Your topics") {
                Text("\(appState.selectedTopics.count) of \(AppState.maxSelectedTopics) selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    ForEach(Topic.allCases) { topic in
                        let isSelected = appState.selectedTopics.contains(topic)
                        let isDisabled = !isSelected && !appState.canSelectMoreTopics

                        Button {
                            appState.toggleTopic(topic)
                        } label: {
                            HStack {
                                Label {
                                    Text(topic.title)
                                } icon: {
                                    Image(systemName: topic.symbolName)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .opacity(isDisabled ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                    }
                }

                Section {
                    ForEach(SourceCategory.allCases) { category in
                        Toggle(isOn: Binding(
                            get: { appState.isSourceCategoryEnabled(category) },
                            set: { appState.setSourceCategory(category, enabled: $0) }
                        )) {
                            Label {
                                Text(category.title)
                            } icon: {
                                Image(systemName: category.symbolName)
                            }
                        }
                    }
                } header: {
                    Text("Sources")
                } footer: {
                    Text("Turn off a source to hide it from the home feed.")
                }

                Section {
                    Toggle("Daily trending alerts", isOn: Binding(
                        get: { appState.notificationsEnabled },
                        set: { appState.setNotificationsEnabled($0) }
                    ))

                    Text("Push delivery is coming soon. Your choice is saved on this device for now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Notifications")
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Reset topic selection", role: .destructive) {
                        appState.resetTopics()
                    }
                } header: {
                    Text("App")
                }

                Section {
                    NavigationLink {
                        SourcesAttributionView()
                    } label: {
                        Label("Content sources", systemImage: "doc.text")
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }

                    NavigationLink {
                        TermsOfUseView()
                    } label: {
                        Label("Terms of use", systemImage: "doc.plaintext")
                    }

                    Link(destination: AppContact.supportURL) {
                        Label("Send feedback", systemImage: "envelope")
                    }

                    LabeledContent("Version", value: appVersionString)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }

    @ViewBuilder
    private var accountSection: some View {
        let auth = appState.authService
        let profile = appState.profileService
        if auth.isSignedIn {
            Section {
                Button {
                    editingName = profile.displayName
                    showEditName = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName.isEmpty ? String(localized: "auth.anonymousUser") : profile.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let email = auth.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "pencil")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                Button("auth.signOut", role: .destructive) {
                    auth.signOut()
                }

                Button("auth.deleteAccount", role: .destructive) {
                    Task {
                        await profile.deleteProfile()
                        await auth.deleteAccount()
                    }
                }
            } header: {
                Text("auth.account")
            }
        }
        else {
            Section {
                Button {
                    showSignIn = true
                } label: {
                    HStack {
                        Label("auth.signIn", systemImage: "person.crop.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("auth.account")
            } footer: {
                Text("auth.signInFooter")
            }
        }
    }
}

private struct SignInView: View {
    let authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await authService.signInWithApple()
                            if authService.isSignedIn { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image("apple_logo")
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text("auth.signInWithApple")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await authService.signInWithGoogle()
                            if authService.isSignedIn { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image("google_logo")
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text("auth.signInWithGoogle")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                dividerWithText("auth.or")

                VStack(spacing: 12) {
                    TextField("auth.email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    SecureField("auth.password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        Task {
                            if isSignUp {
                                await authService.signUpWithEmail(email, password: password)
                            }
                            else {
                                await authService.signInWithEmail(email, password: password)
                            }
                            if authService.isSignedIn { dismiss() }
                        }
                    } label: {
                        Text(isSignUp ? LocalizedStringResource("auth.createAccount") : LocalizedStringResource("auth.signInWithEmail"))
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(email.isEmpty || password.isEmpty)

                    Button {
                        isSignUp.toggle()
                    } label: {
                        Text(isSignUp ? LocalizedStringResource("auth.alreadyHaveAccount") : LocalizedStringResource("auth.noAccount"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("auth.signIn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .overlay {
                if authService.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }

    private func dividerWithText(_ text: LocalizedStringResource) -> some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
    }
}

private struct SourcesAttributionView: View {
    var body: some View {
        List {
            Section {
                Text("DeveloperNews aggregates publicly available developer content. We display headlines, short excerpts, and links — full articles open in the publisher's website inside the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Articles") {
                Text("Curated RSS feeds from independent and company engineering blogs.")
                    .font(.footnote)
                attributionRow("Swift with Majid", url: "https://swiftwithmajid.com")
                attributionRow("InfoQ", url: "https://www.infoq.com")
                attributionRow("GitHub Blog", url: "https://github.blog")
                attributionRow("Mozilla Hacks", url: "https://hacks.mozilla.org")
                attributionRow("Cloudflare Blog", url: "https://blog.cloudflare.com")
                attributionRow("Lobsters", url: "https://lobste.rs")
                attributionRow("Stripe Engineering", url: "https://stripe.com/blog")
                attributionRow("Netflix Tech Blog", url: "https://netflixtechblog.com")
                attributionRow("High Scalability", url: "https://www.highscalability.com")
                attributionRow("Stack Overflow Blog", url: "https://stackoverflow.blog")
                attributionRow("CSS-Tricks", url: "https://css-tricks.com")
                attributionRow("Hacking with Swift", url: "https://www.hackingwithswift.com")
                attributionRow("Donny Wals", url: "https://www.donnywals.com")
            }

            Section("Hacker News") {
                Text("Headlines from the public Hacker News API operated by Y Combinator.")
                    .font(.footnote)
                attributionRow("Hacker News", url: "https://news.ycombinator.com")
            }

            Section("GitHub Trending") {
                Text("Trending repositories from the public GitHub Search API.")
                    .font(.footnote)
                attributionRow("GitHub", url: "https://github.com")
            }

            Section("Reddit") {
                Text("Link posts from a curated set of developer subreddits via Reddit's public listing JSON.")
                    .font(.footnote)
                attributionRow("Reddit", url: "https://www.reddit.com")
            }

            Section {
                Text("All trademarks and logos belong to their respective owners. DeveloperNews is not affiliated with or endorsed by any of the listed sources.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Content sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func attributionRow(_ name: String, url: String) -> some View {
        if let resolved = URL(string: url) {
            Link(destination: resolved) {
                HStack {
                    Text(name)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
        }
        else {
            Text(name)
        }
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    sectionHeader("What we collect")
                    sectionBody("DeveloperNews does not run analytics or third-party tracking SDKs. However, if you sign in with Apple, Google, or email, we collect your email address and display name through Firebase Authentication to manage your account.")

                    sectionHeader("Authentication")
                    sectionBody("Sign-in is powered by Firebase Authentication, a service provided by Google. When you sign in, Firebase stores your email, display name, and account creation date. You can delete your account at any time from Settings, which removes your authentication data from Firebase.")

                    sectionHeader("On-device storage")
                    sectionBody("Your selected topics, saved stories, and preferences are stored only on your device using the system defaults database. They never leave the device unless iCloud sync is enabled by you in iOS settings.")

                    sectionHeader("Network requests")
                    sectionBody("To populate the feed the app requests publicly available content from RSS feeds, the Hacker News API, and the GitHub API. These services may log your IP address and User-Agent like any other web request.")

                    sectionHeader("Article web view")
                    sectionBody("When you open a story the original publisher's web page loads inside an in-app browser. The publisher's own cookies, scripts, and trackers run as if you visited the page in Safari.")

                    sectionHeader("Advertising")
                    sectionBody("If a future version of the app includes advertising, an additional consent screen will be shown before any advertising SDK collects identifiers, in line with Apple's App Tracking Transparency policy.")

                    sectionHeader("Contact")
                    sectionBody("Questions about this policy can be sent through the feedback link in Settings.")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func sectionBody(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
    }
}

private struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    sectionHeader("Use of the app")
                    sectionBody("DeveloperNews is provided as is, without warranty of any kind. You use the app at your own discretion.")

                    sectionHeader("Third party content")
                    sectionBody("Headlines, summaries, thumbnails, and links surfaced inside the app belong to their original publishers. The full article content remains hosted by the publisher and is opened in the publisher's own page when you tap a story.")

                    sectionHeader("Acceptable use")
                    sectionBody("You may not attempt to reverse engineer, redistribute, or scrape content from the app. Use the in-app browser only for personal, non commercial reading.")

                    sectionHeader("Limitation of liability")
                    sectionBody("DeveloperNews is not responsible for the accuracy, availability, or behavior of third party content surfaced through the app, including any links opened in the in-app browser.")

                    sectionHeader("Changes")
                    sectionBody("These terms may be updated when meaningful product changes ship. Continued use of the app after an update constitutes acceptance of the revised terms.")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Terms of use")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func sectionBody(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
    }
}

private struct BookmarkDetailView: View {
    let appState: AppState
    let item: ContentItem
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

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
                            Label("bookmark.openLink", systemImage: "safari")
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
                        Text("bookmark.createdAt")
                        Text(currentItem.publishedAt, style: .date)
                        Text(currentItem.publishedAt, style: .time)
                    }
                    if let updatedAt = currentItem.updatedAt {
                        HStack(spacing: 4) {
                            Text("bookmark.updatedAt")
                            Text(updatedAt, style: .date)
                            Text(updatedAt, style: .time)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

                Button("bookmark.delete", role: .destructive) {
                    showDeleteConfirm = true
                }
                .font(.footnote)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .navigationTitle("bookmark.detail")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("bookmark.deleteConfirm", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                appState.removeSavedItem(at: currentItem.url)
                dismiss()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditBookmarkView(appState: appState, item: currentItem)
        }
    }
}

private struct EditBookmarkView: View {
    let appState: AppState
    let item: ContentItem
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var link: String
    @State private var selectedTopics: Set<Topic>

    init(appState: AppState, item: ContentItem) {
        self.appState = appState
        self.item = item
        _title = State(initialValue: item.title)
        _description = State(initialValue: item.summary)
        _link = State(initialValue: item.hasExternalLink ? item.url.absoluteString : "")
        _selectedTopics = State(initialValue: Set(item.topics))
    }

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLink = !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDescription = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && !selectedTopics.isEmpty && (hasLink || hasDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LimitedTextField(text: $title, limit: 100, prompt: "save.titlePlaceholder")

                    TextField("save.linkPlaceholder", text: $link)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("save.details")
                }

                Section {
                    LimitedTextEditor(text: $description, limit: 1000)
                } header: {
                    Text("save.description")
                }

                Section {
                    ForEach(Topic.allCases) { topic in
                        Button {
                            if selectedTopics.contains(topic) {
                                selectedTopics.remove(topic)
                            }
                            else {
                                selectedTopics.insert(topic)
                            }
                        } label: {
                            HStack {
                                Label {
                                    Text(topic.title)
                                } icon: {
                                    Image(systemName: topic.symbolName)
                                }
                                Spacer()
                                if selectedTopics.contains(topic) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("save.topic")
                }
            }
            .navigationTitle("bookmark.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .scrollDismissesKeyboard(.interactively)
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

        var updated = ContentItem(
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
            updatedAt: .now
        )

        if newURL != item.url {
            appState.removeSavedItem(at: item.url)
            appState.addSavedItem(updated)
        }
        else {
            appState.updateSavedItem(updated)
        }
    }
}

private struct ArticleDetailView: View {
    let appState: AppState
    let item: ContentItem

    private var translator: ContentTranslator { appState.translator }

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var loadProgress: Double = 0
    @State private var reloadTrigger = 0
    @State private var webViewRef: WKWebView?
    @State private var pageTranslationTrigger = 0
    @State private var isTranslatingPage = false
    @State private var isPageTranslated = false

    var body: some View {
        ZStack(alignment: .top) {
            ArticleWebView(
                url: item.url,
                isLoading: $isLoading,
                loadError: $loadError,
                progress: $loadProgress,
                webViewRef: $webViewRef,
                reloadTrigger: reloadTrigger
            )
            .opacity(loadError == nil ? 1 : 0)
            .ignoresSafeArea(edges: .bottom)

            if isLoading && loadProgress < 1 {
                ProgressView(value: max(loadProgress, 0.05))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(height: 2)
                    .transition(.opacity)
            }

            if let message = loadError {
                ContentUnavailableView {
                    Label("Could not load article", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button {
                        loadError = nil
                        reloadTrigger &+= 1
                    } label: {
                        Text("Try again")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)

                    ShareLink(item: item.url, subject: Text(item.title)) {
                        Text("Open elsewhere")
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .overlay {
            if let config = translator.makeConfiguration(), pageTranslationTrigger > 0 {
                Color.clear
                    .id(pageTranslationTrigger)
                    .translationTask(config) { session in
                        await translateWebPage(using: session)
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(translator.title(for: item))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(item.sourceName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.toggleSaved(item)
                } label: {
                    Image(systemName: appState.isSaved(item) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(appState.isSaved(item) ? "Remove from saved" : "Save story")
            }

            if translator.needsTranslation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isPageTranslated {
                            restoreOriginalPage()
                        }
                        else {
                            pageTranslationTrigger &+= 1
                        }
                    } label: {
                        if isTranslatingPage {
                            ProgressView()
                                .controlSize(.small)
                        }
                        else {
                            Image(systemName: "translate")
                                .foregroundStyle(isPageTranslated ? Color.accentColor : Color.primary)
                        }
                    }
                    .disabled(isLoading || isTranslatingPage)
                    .accessibilityLabel("Translate page")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reloadTrigger &+= 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("Reload article")
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: item.url, subject: Text(item.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func translateWebPage(using session: TranslationSession) async {
        guard let webView = webViewRef else { return }
        isTranslatingPage = true

        let extractJS = """
        var els=document.querySelectorAll('p,h1,h2,h3,h4,h5,h6,li,td,th,blockquote,figcaption,dt,dd');
        var r=[];
        for(var i=0;i<els.length;i++){
            var t=els[i].innerText.trim();
            if(t.length>0&&t.length<5000){
                els[i].setAttribute('data-tr-id',String(i));
                els[i].setAttribute('data-tr-orig',els[i].innerText);
                r.push({id:i,text:t});
            }
        }
        return JSON.stringify(r);
        """

        guard let jsonString = try? await webView.callAsyncJavaScript(
            extractJS, contentWorld: .page
        ) as? String,
              let data = jsonString.data(using: .utf8),
              let entries = try? JSONDecoder().decode([PageTextEntry].self, from: data),
              !entries.isEmpty
        else {
            isTranslatingPage = false
            return
        }

        let chunkSize = 15
        for chunkStart in stride(from: 0, to: entries.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, entries.count)
            let chunk = Array(entries[chunkStart..<chunkEnd])
            let requests = chunk.map {
                TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.id))
            }

            var translations: [String: String] = [:]
            do {
                for try await response in session.translate(batch: requests) {
                    if let id = response.clientIdentifier {
                        translations[id] = response.targetText
                    }
                }
            }
            catch {
                continue
            }

            guard !translations.isEmpty else { continue }

            let injectJS = """
            for(var id in translations){
                var el=document.querySelector('[data-tr-id="'+id+'"]');
                if(el) el.innerText=translations[id];
            }
            """
            _ = try? await webView.callAsyncJavaScript(
                injectJS,
                arguments: ["translations": translations],
                contentWorld: .page
            )
        }

        isTranslatingPage = false
        isPageTranslated = true
    }

    private func restoreOriginalPage() {
        guard let webView = webViewRef else { return }

        let restoreJS = """
        var els=document.querySelectorAll('[data-tr-orig]');
        for(var i=0;i<els.length;i++){
            els[i].innerText=els[i].getAttribute('data-tr-orig');
        }
        """
        webView.evaluateJavaScript(restoreJS)
        isPageTranslated = false
    }
}

private struct PageTextEntry: Decodable {
    let id: Int
    let text: String
}
