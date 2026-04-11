import SwiftUI
import WebKit

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
    @State private var topicFilters: Set<Topic> = []

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
                showsSummary: false
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
    @Binding var selectedFilters: Set<Topic>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FocusChip(
                    title: "All",
                    systemImage: "square.grid.2x2",
                    isSelected: selectedFilters.isEmpty
                ) {
                    selectedFilters.removeAll()
                }

                ForEach(availableTopics) { topic in
                    FocusChip(
                        title: topic.title,
                        systemImage: topic.symbolName,
                        isSelected: selectedFilters.contains(topic)
                    ) {
                        if selectedFilters.contains(topic) {
                            selectedFilters.remove(topic)
                        }
                        else {
                            selectedFilters.insert(topic)
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

private struct ArticleWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else {
            return
        }
        context.coordinator.loadedURL = url
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ArticleWebView
        var loadedURL: URL?

        init(parent: ArticleWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.loadError = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }
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
                    sectionBody("DeveloperNews collects no personal information. We do not run analytics, telemetry, or any third party tracking SDK that identifies you.")

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

private struct ArticleDetailView: View {
    let appState: AppState
    let item: ContentItem

    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            ArticleWebView(url: item.url, isLoading: $isLoading, loadError: $loadError)
                .opacity(loadError == nil ? 1 : 0)
                .ignoresSafeArea(edges: .bottom)

            if isLoading && loadError == nil {
                ProgressView()
                    .controlSize(.large)
            }

            if let loadError {
                ContentUnavailableView {
                    Label("Could not load article", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(loadError)
                } actions: {
                    ShareLink(item: item.url, subject: Text(item.title)) {
                        Text("Open elsewhere")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .background(Color(.systemBackground))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(item.title)
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
                    appState.toggleSaved(itemID: item.id)
                } label: {
                    Image(systemName: appState.savedItemIDs.contains(item.id) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(appState.savedItemIDs.contains(item.id) ? "Remove from saved" : "Save story")
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
}
