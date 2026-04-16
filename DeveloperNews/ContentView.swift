import AuthenticationServices
import CoreImage.CIFilterBuiltins
import SwiftUI
import Translation
import WebKit

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

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

private struct DraftEditorScreen: View {
    let navigationTitle: LocalizedStringResource
    let saveTitle: LocalizedStringResource
    let titleLimit: Int
    let descriptionLimit: Int
    let onSave: (String, String, String, Set<Topic>) -> Void

    @Environment(\.dismiss) private var dismiss

    @Binding var title: String
    @Binding var description: String
    @Binding var link: String
    @Binding var selectedTopics: Set<Topic>

    init(
        navigationTitle: LocalizedStringResource,
        saveTitle: LocalizedStringResource,
        title: Binding<String>,
        description: Binding<String>,
        link: Binding<String>,
        selectedTopics: Binding<Set<Topic>>,
        titleLimit: Int = 100,
        descriptionLimit: Int = 1000,
        onSave: @escaping (String, String, String, Set<Topic>) -> Void
    ) {
        self.navigationTitle = navigationTitle
        self.saveTitle = saveTitle
        self.titleLimit = titleLimit
        self.descriptionLimit = descriptionLimit
        self.onSave = onSave
        _title = title
        _description = description
        _link = link
        _selectedTopics = selectedTopics
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
                    LimitedTextField(text: $title, limit: titleLimit, prompt: "save.titlePlaceholder")

                    TextField("save.linkPlaceholder", text: $link)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("save.details")
                }

                Section {
                    LimitedTextEditor(text: $description, limit: descriptionLimit)
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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) {
                        onSave(title, description, link, selectedTopics)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct SavedItemNoteComposerView: View {
    let appState: AppState
    let item: ContentItem
    @Environment(\.dismiss) private var dismiss

    @State private var description: String

    init(appState: AppState, item: ContentItem) {
        self.appState = appState
        self.item = item
        _description = State(initialValue: item.summary)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.sourceName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(item.url.absoluteString)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            UIPasteboard.general.string = item.url.absoluteString
                        } label: {
                            Label("Copy link", systemImage: "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("save.description")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LimitedTextEditor(text: $description, limit: 2000)
                    }
                }
                .padding(20)
            }
            .navigationTitle("saved.editNote")
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
                }
            }
        }
    }

    private func saveChanges() {
        guard let saved = appState.savedItemSnapshots[item.url] else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = ContentItem(
            id: saved.id,
            kind: saved.kind,
            title: saved.title,
            summary: trimmed,
            sourceName: saved.sourceName,
            sourceCategory: saved.sourceCategory,
            authorName: saved.authorName,
            url: saved.url,
            publishedAt: saved.publishedAt,
            topics: saved.topics,
            trendScore: saved.trendScore,
            thumbnailURL: saved.thumbnailURL,
            engagement: saved.engagement,
            isUserCreated: saved.isUserCreated,
            updatedAt: .now
        )
        appState.updateSavedItem(updated)
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
    @State private var isToastVisible = false
    @State private var toastDismissTask: Task<Void, Never>?
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
        .overlay(alignment: .top) {
            if isToastVisible, let message = appState.toastMessage {
                ToastView(message: message)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: appState.toastTrigger) { _, _ in
            guard appState.toastMessage != nil else { return }
            toastDismissTask?.cancel()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isToastVisible = true
            }
            toastDismissTask = Task {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    isToastVisible = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, appState.isOnboardingComplete else {
                return
            }
            appState.processPendingSharedItems()
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
            appState.processPendingSharedItems()
        }
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.85))
            }
            .shadow(color: Color.black.opacity(0.25), radius: 8, y: 3)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
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
                    Label("Bookmarks", systemImage: "bookmark")
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
    @State private var searchQuery = ""

    var body: some View {
        let topItem = shouldShowTopStory && searchQuery.isEmpty ? appState.personalizedItems.first : nil

        NavigationStack {
            VStack(spacing: 0) {
                if appState.selectedTopics.count > 1 {
                    HomeTopicFocusBar(appState: appState)
                }

                feedContent(topItem: topItem)
            }
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search stories")
            .refreshable {
                await appState.reload()
            }
        }
    }

    private func searchFiltered(_ items: [ContentItem]) -> [ContentItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        let needle = query.lowercased()
        return items.filter {
            $0.title.lowercased().contains(needle) ||
            $0.summary.lowercased().contains(needle) ||
            $0.sourceName.lowercased().contains(needle)
        }
    }

    private var shouldShowTopStory: Bool {
        guard !appState.isTopStoryHidden else { return false }
        guard !appState.personalizedItems.isEmpty else { return false }
        return !appState.isLoading || appState.hasLoadedContent
    }

    @ViewBuilder
    private func feedContent(topItem: ContentItem?) -> some View {
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
                    let filteredArticles = searchFiltered(appState.pagedArticleItems)
                    let filteredDiscussions = searchFiltered(appState.pagedDiscussionItems)
                    let articleItems = topItem.map { top in
                        filteredArticles.filter { $0.id != top.id }
                    } ?? filteredArticles
                    let discussionItems = topItem.map { top in
                        filteredDiscussions.filter { $0.id != top.id }
                    } ?? filteredDiscussions

                    FeedSectionListView(
                        appState: appState,
                        articleItems: articleItems,
                        discussionItems: discussionItems,
                        hasMore: appState.hasMorePages,
                        onLoadMore: { appState.loadMore() },
                        scrollToTopTrigger: appState.homeScrollToTopTrigger,
                        topContent: topItem.map { item in
                            AnyView(
                                HomeTopStoryCard(appState: appState, item: item)
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 4)
                            )
                        }
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
            .navigationTitle("Bookmarks")
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
    var topContent: AnyView? = nil

    @State private var selectedAuthor: AuthorInfo?

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
        .navigationDestination(item: $selectedAuthor) { author in
            UserProfileView(
                appState: appState,
                authorId: author.id,
                authorName: author.name,
                authorEmoji: author.emoji
            )
        }
    }

    private var list: some View {
        List {
            if let topContent {
                Section {
                    topContent
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            }

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
                        FeedItemRow(appState: appState, item: item, selectedAuthor: $selectedAuthor)
                    }
                }
            }

            if !discussionItems.isEmpty {
                Section("Discussions") {
                    ForEach(discussionItems) { item in
                        FeedItemRow(appState: appState, item: item, selectedAuthor: $selectedAuthor)
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

            if translator.canTranslate {
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
    var selectedAuthor: Binding<AuthorInfo?>

    private var translator: ContentTranslator { appState.translator }

    @State private var translationTrigger = 0
    @State private var showingTranslation = false

    private var displayTitle: String {
        showingTranslation ? translator.title(for: item) : item.title
    }

    private var displaySummary: String {
        showingTranslation ? translator.summary(for: item) : item.summary
    }

    private var followingPost: CommunityPost? {
        guard item.sourceCategory == .following,
              let postId = item.url.pathComponents.last
        else { return nil }
        return appState.communityService.posts.first { $0.id == postId }
    }

    var body: some View {
        NavigationLink {
            if item.sourceCategory == .following,
               let postId = item.url.pathComponents.last,
               let post = appState.communityService.posts.first(where: { $0.id == postId }) {
                CommunityPostDetailView(appState: appState, post: post)
            }
            else if item.isUserCreated {
                BookmarkDetailView(appState: appState, item: item)
            }
            else {
                ArticleDetailView(appState: appState, item: item)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                FeedItemMetaView(appState: appState, item: item, authorEmoji: followingPost.flatMap { appState.communityService.authorEmoji(for: $0.authorId) }) {
                    guard let post = followingPost else { return }
                    selectedAuthor.wrappedValue = AuthorInfo(
                        id: post.authorId,
                        name: post.authorName,
                        emoji: appState.communityService.authorEmoji(for: post.authorId)
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundStyle(appState.isRead(item) ? .secondary : .primary)
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

                if translator.canTranslate {
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
    let appState: AppState
    let item: ContentItem
    var authorEmoji: String?
    var onAuthorTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if item.sourceCategory != .following {
                    Image(systemName: item.kind.symbolName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if item.sourceCategory == .following, let onAuthorTap {
                    Button {
                        onAuthorTap()
                    } label: {
                        HStack(spacing: 4) {
                            if let emoji = authorEmoji {
                                Text(emoji)
                                    .font(.caption)
                            }
                            else {
                                Image(systemName: "questionmark.circle.dashed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.sourceName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .underline()
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .buttonStyle(.plain)
                }
                else {
                    Text(item.sourceName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

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

private let translationLanguages: [(code: String, name: String)] = [
    ("ko", "한국어"),
    ("ja", "日本語"),
    ("zh-Hans", "简体中文"),
    ("zh-Hant", "繁體中文"),
    ("es", "Español"),
    ("fr", "Français"),
    ("de", "Deutsch"),
    ("pt-BR", "Português"),
    ("ru", "Русский"),
    ("ar", "العربية"),
    ("hi", "हिन्दी"),
    ("vi", "Tiếng Việt"),
    ("th", "ไทย"),
    ("id", "Bahasa Indonesia"),
]

private let appVersionString: String = {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "0.0"
    let build = info?["CFBundleVersion"] as? String ?? "0"
    return "\(version) (\(build))"
}()

// MARK: - Community

private struct AuthorInfo: Hashable {
    let id: String
    let name: String
    let emoji: String?
}

private struct CommunityView: View {
    let appState: AppState
    @State private var showCreatePost = false
    @State private var selectedAuthor: AuthorInfo?
    @State private var searchQuery = ""

    private var community: CommunityService { appState.communityService }
    private var currentUserId: String? { appState.authService.userId }

    private var searchFilteredPosts: [CommunityPost] {
        let posts = community.filteredPosts(excludingUserIds: appState.blockedUserIds)
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return posts }
        let needle = query.lowercased()
        return posts.filter {
            $0.title.lowercased().contains(needle) ||
            $0.description.lowercased().contains(needle) ||
            $0.authorName.lowercased().contains(needle)
        }
    }

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
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "community.searchPrompt")
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
                ForEach(searchFilteredPosts) { post in
                    NavigationLink {
                        CommunityPostDetailView(appState: appState, post: post)
                    } label: {
                        CommunityPostRow(appState: appState, post: post) {
                            selectedAuthor = AuthorInfo(id: post.authorId, name: post.authorName, emoji: appState.communityService.authorEmoji(for: post.authorId))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(item: $selectedAuthor) { author in
                UserProfileView(appState: appState, authorId: author.id, authorName: author.name, authorEmoji: author.emoji)
            }
            .refreshable {
                await community.refresh()
            }
        }
    }
}

private struct CommunityPostRow: View {
    let appState: AppState
    let post: CommunityPost
    var onAuthorTap: (() -> Void)?

    private var currentUserId: String? { appState.authService.userId }
    private var isLiked: Bool {
        guard let uid = currentUserId else { return false }
        return post.likedBy.contains(uid)
    }

    @ViewBuilder
    private var authorIcon: some View {
        if let emoji = appState.communityService.authorEmoji(for: post.authorId) {
            Text(emoji)
                .font(.caption)
        }
        else {
            Image(systemName: "questionmark.circle.dashed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let onAuthorTap {
                    Button {
                        onAuthorTap()
                    } label: {
                        HStack(spacing: 4) {
                            authorIcon
                            Text(post.authorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .underline()
                        }
                    }
                    .buttonStyle(.plain)
                }
                else {
                    authorIcon
                    Text(post.authorName)
                        .font(.caption.weight(.semibold))
                }
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(relativeDateFormatter.localizedString(for: post.createdAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(post.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appState.isPostRead(post.id) ? .secondary : .primary)
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
    @State private var showEditPost = false
    @State private var showDeleteConfirm = false
    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false
    @State private var showOtherReasonInput = false
    @State private var otherReasonText = ""
    @State private var alreadyReported = false
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
                    NavigationLink {
                        UserProfileView(appState: appState, authorId: currentPost.authorId, authorName: currentPost.authorName, authorEmoji: community.authorEmoji(for: currentPost.authorId))
                    } label: {
                        HStack(spacing: 4) {
                            if let emoji = community.authorEmoji(for: currentPost.authorId) {
                                Text(emoji)
                            }
                            Text(currentPost.authorName)
                                .font(.caption.weight(.semibold))
                                .underline()
                        }
                    }
                    .buttonStyle(.plain)

                    if !isAuthor, currentUserId != nil {
                        Button {
                            Task {
                                await appState.profileService.toggleFollow(currentPost.authorId)
                            }
                        } label: {
                            Text(appState.profileService.isFollowing(currentPost.authorId)
                                 ? LocalizedStringResource("community.following")
                                 : LocalizedStringResource("community.follow"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    appState.profileService.isFollowing(currentPost.authorId)
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                )
                                .foregroundStyle(
                                    appState.profileService.isFollowing(currentPost.authorId)
                                        ? Color.white
                                        : Color.primary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

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

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("community.createdAt")
                        Text(currentPost.createdAt, style: .date)
                        Text(currentPost.createdAt, style: .time)
                    }
                    if let updatedAt = currentPost.updatedAt {
                        HStack(spacing: 4) {
                            Text("community.updatedAt")
                            Text(updatedAt, style: .date)
                            Text(updatedAt, style: .time)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

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
                else if currentUserId != nil {
                    HStack(spacing: 16) {
                        Button("community.report") {
                            showReportConfirm = true
                        }
                        .disabled(alreadyReported)
                        .foregroundStyle(alreadyReported ? Color.secondary : Color.red)

                        Button("community.blockUser") {
                            showBlockConfirm = true
                        }
                        .foregroundStyle(.red)
                    }
                    .font(.footnote)

                    if alreadyReported {
                        Text("community.alreadyReported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isAuthor {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditPost = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("community.editPost")
                }
            }
        }
        .sheet(isPresented: $showEditPost) {
            EditCommunityPostView(appState: appState, post: currentPost)
        }
        .confirmationDialog("community.deleteConfirm", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await community.deletePost(currentPost)
                    dismiss()
                }
            }
        }
        .confirmationDialog("community.reportConfirmTitle", isPresented: $showReportConfirm, titleVisibility: .visible) {
            Button("community.reportReasonSpam") {
                submitReport("spam")
            }
            Button("community.reportReasonInappropriate") {
                submitReport("inappropriate")
            }
            Button("community.reportReasonOther") {
                otherReasonText = ""
                showOtherReasonInput = true
            }
        }
        .alert("community.reportReasonOtherTitle", isPresented: $showOtherReasonInput) {
            TextField("community.reportReasonOtherPlaceholder", text: $otherReasonText)
                .onChange(of: otherReasonText) { _, new in
                    if new.count > 200 { otherReasonText = String(new.prefix(200)) }
                }
            Button("Cancel", role: .cancel) {}
            Button("community.report") {
                let trimmed = otherReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                submitReport("other: \(trimmed)")
            }
        } message: {
            Text("community.reportReasonOtherMessage")
        }
        .confirmationDialog("community.blockConfirmTitle", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("community.blockConfirmAction", role: .destructive) {
                appState.blockUser(currentPost.authorId)
                dismiss()
            }
        } message: {
            Text("community.blockConfirmMessage")
        }
        .onAppear {
            appState.markPostAsRead(post.id)
            appState.markURLAsRead("devnews://community/\(post.id)")
            Task {
                guard let uid = currentUserId else { return }
                alreadyReported = await community.hasReportedPost(post.id, reporterId: uid)
            }
        }
    }

    private func submitReport(_ reason: String) {
        guard let uid = currentUserId else { return }
        Task {
            await community.reportPost(currentPost, reporterId: uid, reason: reason)
            alreadyReported = true
        }
    }
}

private struct CommunityPostEditorView: View {
    let appState: AppState
    let existingPost: CommunityPost?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var link: String
    @State private var selectedTopics: Set<Topic>

    init(appState: AppState, existingPost: CommunityPost? = nil) {
        self.appState = appState
        self.existingPost = existingPost
        _title = State(initialValue: existingPost?.title ?? "")
        _description = State(initialValue: existingPost?.description ?? "")
        _link = State(initialValue: existingPost?.link ?? "")
        _selectedTopics = State(initialValue: Set(existingPost?.topics ?? []))
    }

    private var isEditing: Bool { existingPost != nil }

    var body: some View {
        DraftEditorScreen(
            navigationTitle: isEditing ? "community.editPost" : "community.newPost",
            saveTitle: isEditing ? "community.savePost" : "community.post",
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
                    editorId: userId
                )
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
                    authorDisplayName: appState.profileService.displayName
                )
            }
        }
    }
}

private struct UserProfileView: View {
    let appState: AppState
    let authorId: String
    let authorName: String
    let authorEmoji: String?

    @State private var followerCount = 0
    @State private var followingCount = 0

    private var currentUserId: String? { appState.authService.userId }
    private var isOwnProfile: Bool { currentUserId == authorId }

    private var authorPosts: [CommunityPost] {
        appState.communityService.posts.filter { $0.authorId == authorId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    if let authorEmoji {
                        Text(authorEmoji)
                            .font(.system(size: 60))
                    }
                    else {
                        Image(systemName: "questionmark.circle.dashed")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                    }

                    Text(authorName)
                        .font(.title3.bold())

                    HStack(spacing: 20) {
                        VStack {
                            Text("\(authorPosts.count)")
                                .font(.headline)
                            Text("profile.posts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(followerCount)")
                                .font(.headline)
                            Text("profile.followers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(followingCount)")
                                .font(.headline)
                            Text("community.following")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            let totalLikes = authorPosts.reduce(0) { $0 + $1.likeCount }
                            Text("\(totalLikes)")
                                .font(.headline)
                            Text("profile.likes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !isOwnProfile, currentUserId != nil {
                        Button {
                            Task {
                                await appState.profileService.toggleFollow(authorId)
                                followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
                            }
                        } label: {
                            Text(appState.profileService.isFollowing(authorId)
                                 ? LocalizedStringResource("community.following")
                                 : LocalizedStringResource("community.follow"))
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 120, height: 34)
                                .background(
                                    appState.profileService.isFollowing(authorId)
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                )
                                .foregroundStyle(
                                    appState.profileService.isFollowing(authorId)
                                        ? Color.white
                                        : Color.primary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 20)

                if authorPosts.isEmpty {
                    Text("profile.noPosts")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
                else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(authorPosts) { post in
                            NavigationLink {
                                CommunityPostDetailView(appState: appState, post: post)
                            } label: {
                                CommunityPostRow(appState: appState, post: post)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
            followingCount = await appState.profileService.fetchFollowingCount(for: authorId)
        }
    }
}

private struct CreatePostView: View {
    let appState: AppState
    var body: some View {
        CommunityPostEditorView(appState: appState)
    }
}

private struct EditCommunityPostView: View {
    let appState: AppState
    let post: CommunityPost

    var body: some View {
        CommunityPostEditorView(appState: appState, existingPost: post)
    }
}

// MARK: - Saved

private struct AddSavedItemView: View {
    let appState: AppState

    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var selectedTopics: Set<Topic> = []

    var body: some View {
        DraftEditorScreen(
            navigationTitle: "save.addItem",
            saveTitle: "Save",
            title: $title,
            description: $description,
            link: $link,
            selectedTopics: $selectedTopics
        ) { _, _, _, _ in
            saveItem()
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

private struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    private static let instagramURLString = "https://www.instagram.com/developernews.zizic?igsh=dnRzMTBnNms0ZjRw&utm_source=qr"

    private var instagramURL: URL {
        URL(string: Self.instagramURLString)!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let qr = QRCodeGenerator.generate(from: Self.instagramURLString) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260)
                            .padding(.top, 24)
                    }

                    Text(try! AttributedString(markdown: String(localized: "feedback.instagramMessage"), options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Link(destination: instagramURL) {
                        HStack {
                            Image(systemName: "camera.circle.fill")
                            Text("@developernews.zizic")
                                .font(.body.weight(.semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
            .navigationTitle("Send feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

enum QRCodeGenerator {
    static func generate(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(string.utf8), forKey: "inputMessage")
        filter?.setValue("H", forKey: "inputCorrectionLevel")

        guard let output = filter?.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct SettingsView: View {
    let appState: AppState

    @State private var showSignIn = false
    @State private var showEditName = false
    @State private var showEmojiPicker = false
    @State private var showFeedback = false
    @State private var showDeleteAccountConfirm = false
    @State private var editingName = ""
    @State private var editingEmoji = ""

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
                SignInView(appState: appState)
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
            .alert("profile.editEmoji", isPresented: $showEmojiPicker) {
                TextField("profile.emojiPlaceholder", text: $editingEmoji)
                    .onChange(of: editingEmoji) { _, new in
                        let emojis = new.filter(\.isEmoji)
                        if let last = emojis.last {
                            editingEmoji = String(last)
                        }
                        else {
                            editingEmoji = ""
                        }
                    }
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    guard !editingEmoji.isEmpty else { return }
                    Task {
                        await appState.profileService.updateProfileEmoji(editingEmoji)
                    }
                }
            } message: {
                Text("profile.editEmojiMessage")
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
                    .presentationDetents([.large])
            }
            .confirmationDialog(
                "auth.deleteAccount.confirmTitle",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("auth.deleteAccount.confirmAction", role: .destructive) {
                    Task {
                        await appState.deleteCurrentAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("auth.deleteAccount.confirmMessage")
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

                    Picker(selection: Binding(
                        get: { appState.translator.targetLanguageCode ?? "" },
                        set: { appState.setTranslationLanguage($0.isEmpty ? nil : $0) }
                    )) {
                        Text("settings.translationOff").tag("")
                        ForEach(translationLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    } label: {
                        Label("settings.translation", systemImage: "translate")
                    }

                    Button("Reset topic selection", role: .destructive) {
                        appState.resetTopics()
                    }

                    NavigationLink {
                        BlockedUsersView(appState: appState)
                    } label: {
                        HStack {
                            Label("settings.blockedUsers", systemImage: "person.slash")
                            Spacer()
                            if !appState.blockedUserIds.isEmpty {
                                Text("\(appState.blockedUserIds.count)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
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

                    Button {
                        showFeedback = true
                    } label: {
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
                NavigationLink {
                    UserProfileView(
                        appState: appState,
                        authorId: auth.userId ?? "",
                        authorName: profile.displayName,
                        authorEmoji: profile.profileEmoji
                    )
                } label: {
                    HStack(spacing: 12) {
                        if let emoji = profile.profileEmoji {
                            Text(emoji)
                                .font(.system(size: 36))
                        }
                        else {
                            Image(systemName: "questionmark.circle.dashed")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                        }

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
                    }
                }
                .padding(.vertical, 4)

                Button {
                    editingEmoji = ""
                    showEmojiPicker = true
                } label: {
                    Label("profile.changeEmoji", systemImage: "face.smiling")
                }

                Button {
                    editingName = profile.displayName
                    showEditName = true
                } label: {
                    Label("profile.changeName", systemImage: "pencil")
                }

                Button("auth.signOut", role: .destructive) {
                    appState.signOut()
                }

                Button("auth.deleteAccount", role: .destructive) {
                    showDeleteAccountConfirm = true
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
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var hasAgreedToTerms = false
    @State private var showPasswordReset = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false

    private var authService: AuthService { appState.authService }

    private var isEmailFormatValid: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private var showEmailFormatError: Bool {
        !email.isEmpty && !isEmailFormatValid
    }

    private var canSubmitEmailForm: Bool {
        guard !email.isEmpty, !password.isEmpty, isEmailFormatValid else { return false }
        if isSignUp { return hasAgreedToTerms }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    termsCheckbox

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                _ = await authService.signInWithApple()
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
                                    .stroke(Color.accentColor, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasAgreedToTerms)
                        .opacity(hasAgreedToTerms ? 1 : 0.5)

                        Button {
                            Task {
                                _ = await authService.signInWithGoogle()
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
                                    .stroke(Color.accentColor, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasAgreedToTerms)
                        .opacity(hasAgreedToTerms ? 1 : 0.5)
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

                        if showEmailFormatError {
                            Text("auth.error.invalidEmail")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        SecureField("auth.password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            Task {
                                if isSignUp {
                                    _ = await authService.signUpWithEmail(email, password: password)
                                }
                                else {
                                    _ = await authService.signInWithEmail(email, password: password)
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
                        .disabled(!canSubmitEmailForm)

                        if !isSignUp {
                            Button {
                                authService.setErrorMessage(nil)
                                showPasswordReset = true
                            } label: {
                                Text("auth.forgotPassword")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            authService.setErrorMessage(nil)
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
                }
                .padding(20)
            }
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
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView(authService: authService)
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                NavigationStack { PrivacyPolicyView() }
            }
            .sheet(isPresented: $showTermsOfUse) {
                NavigationStack { TermsOfUseView() }
            }
        }
    }

    private var termsCheckbox: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                hasAgreedToTerms.toggle()
            } label: {
                Image(systemName: hasAgreedToTerms ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(hasAgreedToTerms ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Text(termsAgreementAttributed)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .tint(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "devnews" {
                        if url.host == "terms" {
                            showTermsOfUse = true
                            return .handled
                        }
                        if url.host == "privacy" {
                            showPrivacyPolicy = true
                            return .handled
                        }
                    }
                    return .systemAction
                })
        }
    }

    private var termsAgreementAttributed: AttributedString {
        let raw = String(localized: "auth.termsAgreement")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: raw, options: options)) ?? AttributedString(raw)
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

private struct PasswordResetView: View {
    let authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var successMessage: String?

    private var isEmailFormatValid: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("auth.passwordReset.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("auth.email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    Task {
                        successMessage = nil
                        let result = await authService.sendPasswordReset(email: email)
                        if case .success = result {
                            successMessage = String(localized: "auth.passwordReset.success")
                        }
                    }
                } label: {
                    Text("auth.passwordReset.send")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!isEmailFormatValid)

                if let successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.leading)
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("auth.passwordReset.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authService.setErrorMessage(nil)
                        dismiss()
                    }
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
}

private struct BlockedUsersView: View {
    let appState: AppState

    var body: some View {
        Group {
            if appState.blockedUserIds.isEmpty {
                ContentUnavailableView("settings.noBlockedUsers", systemImage: "person.slash")
            }
            else {
                List {
                    ForEach(Array(appState.blockedUserIds), id: \.self) { userId in
                        HStack {
                            Text(userId)
                                .font(.footnote)
                                .lineLimit(1)
                            Spacer()
                            Button("settings.unblock", role: .destructive) {
                                appState.unblockUser(userId)
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.blockedUsers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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

            Section("Blogs & Articles") {
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
        .toolbar(.hidden, for: .tabBar)
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
    private static let notionURL = URL(string: "https://profuse-scaffold-962.notion.site/PrivacyInfo-34138d63664180fc9fb0d2604090aad5")!

    var body: some View {
        SimpleWebView(url: Self.notionURL)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Privacy policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}

private struct SimpleWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
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
        .toolbar(.hidden, for: .tabBar)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            appState.markAsRead(currentItem)
        }
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

    var body: some View {
        DraftEditorScreen(
            navigationTitle: "bookmark.edit",
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

        let updated = ContentItem(
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
    @State private var showEditNote = false

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

            if appState.isSaved(item) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditNote = true
                    } label: {
                        Image(systemName: currentNote.isEmpty ? "note.text.badge.plus" : "note.text")
                            .foregroundStyle(currentNote.isEmpty ? Color.primary : Color.accentColor)
                    }
                }
            }

            if translator.canTranslate {
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
        .onAppear {
            appState.markAsRead(item)
        }
        .sheet(isPresented: $showEditNote) { noteEditorSheet }
    }

    private var currentNote: String {
        appState.savedItemSnapshots[item.url]?.summary ?? ""
    }

    @ViewBuilder
    private var noteEditorSheet: some View {
        SavedItemNoteComposerView(appState: appState, item: appState.savedItemSnapshots[item.url] ?? item)
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
