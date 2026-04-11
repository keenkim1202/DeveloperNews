import SafariServices
import SwiftUI

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter
}()

@MainActor
struct ContentView: View {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    private static let staleThreshold: TimeInterval = 15 * 60

    var body: some View {
        Group {
            if appState.isOnboardingComplete {
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
    @Bindable var appState: AppState

    var body: some View {
        TabView(selection: $appState.currentTab) {
            HomeView(appState: appState)
                .tabItem {
                    Label("Home", systemImage: "newspaper")
                }
                .tag(AppTab.home)

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
                    ContentUnavailableView(
                        "Loading stories",
                        systemImage: "newspaper",
                        description: Text("Fetching the latest developer stories for your selected topics.")
                    )
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
                        appState.articleItems.filter { $0.id != top.id }
                    } ?? appState.articleItems
                    let discussionItems = topItem.map { top in
                        appState.discussionItems.filter { $0.id != top.id }
                    } ?? appState.discussionItems

                    FeedSectionListView(
                        appState: appState,
                        articleItems: articleItems,
                        discussionItems: discussionItems
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
                    title: "All",
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
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
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

    private var matchingArticleItems: [ContentItem] {
        filtered(appState.savedArticleItems)
    }

    private var matchingDiscussionItems: [ContentItem] {
        filtered(appState.savedDiscussionItems)
    }

    private var hasAnyMatches: Bool {
        !matchingArticleItems.isEmpty || !matchingDiscussionItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
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
                    ContentUnavailableView.search(text: searchQuery)
                }
                else {
                    FeedSectionListView(
                        appState: appState,
                        articleItems: matchingArticleItems,
                        discussionItems: matchingDiscussionItems,
                        showsSummary: false
                    )
                }
            }
            .navigationTitle("Saved")
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search saved stories")
            .toolbar {
                if !appState.savedItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
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
                            Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                        }
                    }
                }
            }
        }
    }

    private func filtered(_ items: [ContentItem]) -> [ContentItem] {
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
}

private struct FeedSectionListView: View {
    let appState: AppState
    let articleItems: [ContentItem]
    let discussionItems: [ContentItem]
    var showsSummary = true

    var body: some View {
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
                Section("Top Stories") {
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
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}

private struct HomeTopStoryCard: View {
    let appState: AppState
    let item: ContentItem

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
                ArticleDetailView(appState: appState, item: item)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    HomeTopStoryThumbnail(url: item.thumbnailURL)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    var body: some View {
        NavigationLink {
            ArticleDetailView(appState: appState, item: item)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                FeedItemMetaView(item: item)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let thumbnailURL = item.thumbnailURL {
                            FeedItemThumbnailView(url: thumbnailURL)
                        }
                    }

                    Text(item.summary)
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
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.leading, -8)
                    .scrollClipDisabled()
                }

                if let engagement = item.engagement {
                    EngagementSummaryView(engagement: engagement)
                }
            }
            .padding(.vertical, 4)
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

private struct EngagementInline: View {
    let systemImage: String
    let value: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text("\(value)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct DetailHeroImageView: View {
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
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                Color(.tertiarySystemFill)
                    .overlay { ProgressView() }
            @unknown default:
                Color(.tertiarySystemFill)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .clipped()
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

private struct SettingsView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            List {
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
                                Label(topic.title, systemImage: topic.symbolName)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
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
                            Label(category.title, systemImage: category.symbolName)
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
                    Button("Reset topic selection", role: .destructive) {
                        appState.resetTopics()
                    }
                } header: {
                    Text("App")
                }

                Section {
                    LabeledContent("Version", value: appVersionString)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct ArticleDetailView: View {
    let appState: AppState
    let item: ContentItem

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingSourceBrowser = false

    var body: some View {
        List {
            if let thumbnailURL = item.thumbnailURL {
                Section {
                    DetailHeroImageView(url: thumbnailURL)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.title)
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Label(item.kind.title, systemImage: item.kind.symbolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Text(item.sourceName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Text(relativeDateFormatter.localizedString(for: item.publishedAt, relativeTo: .now))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let engagement = item.engagement {
                                Text("·")
                                    .foregroundStyle(.tertiary)

                                EngagementInline(systemImage: "arrow.up", value: engagement.reactionCount)
                                EngagementInline(systemImage: "bubble.left", value: engagement.commentCount)
                            }
                        }

                        if let authorName = item.authorName {
                            Text("By \(authorName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(item.summary)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }

            Section("Topics") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.topics) { topic in
                            let canFocus = appState.selectedTopics.contains(topic)
                            Button {
                                guard canFocus else { return }
                                appState.focusedTopic = topic
                                appState.currentTab = .home
                                dismiss()
                            } label: {
                                Text(topic.title)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canFocus)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            }

            Section("Actions") {
                Button {
                    appState.toggleSaved(itemID: item.id)
                } label: {
                    let isSaved = appState.savedItemIDs.contains(item.id)
                    Label(
                        isSaved ? "Remove from saved items" : "Save to saved items",
                        systemImage: isSaved ? "bookmark.slash" : "bookmark"
                    )
                }

                Button {
                    isShowingSourceBrowser = true
                } label: {
                    Label("Read original source", systemImage: "safari")
                }

                ShareLink(item: item.url, subject: Text(item.title)) {
                    Label("Share story link", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingSourceBrowser) {
            SafariBrowserView(url: item.url)
                .ignoresSafeArea()
        }
    }
}

private struct SafariBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
