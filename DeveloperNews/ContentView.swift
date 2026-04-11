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

private enum AppTab: Hashable {
    case home
    case saved
    case settings
}

private struct MainTabView: View {
    let appState: AppState
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(appState: appState)
                .tabItem {
                    Label("Home", systemImage: "newspaper")
                }
                .tag(AppTab.home)

            SavedView(appState: appState, selectedTab: $selectedTab)
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
        NavigationStack {
            Group {
                if appState.isLoading && !appState.hasLoadedContent {
                    ContentUnavailableView(
                        "Loading stories",
                        systemImage: "newspaper",
                        description: Text("Fetching the latest developer stories for your selected topics.")
                    )
                }
                else if let errorMessage = appState.errorMessage, !appState.hasLoadedContent {
                    ContentUnavailableView(
                        "Could not load stories",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                }
                else if appState.personalizedItems.isEmpty {
                    ContentUnavailableView(
                        "No stories for current topics",
                        systemImage: "tray",
                        description: Text("Try choosing a few more topics or refresh again in a moment.")
                    )
                }
                else {
                    FeedSectionListView(
                        appState: appState,
                        articleItems: appState.articleItems,
                        discussionItems: appState.discussionItems
                    )
                    .overlay {
                        if appState.isLoading {
                            ProgressView()
                                .controlSize(.regular)
                        }
                    }
                }
            }
            .navigationTitle("Trending")
            .refreshable {
                await appState.reload()
            }
        }
    }
}

private struct SavedView: View {
    let appState: AppState
    @Binding var selectedTab: AppTab

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
                            selectedTab = .home
                        } label: {
                            Text("Browse trending")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                else {
                    FeedSectionListView(
                        appState: appState,
                        articleItems: appState.savedArticleItems,
                        discussionItems: appState.savedDiscussionItems,
                        showsSummary: false
                    )
                }
            }
            .navigationTitle("Saved")
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(articleItems.count + discussionItems.count) stories across your selected topics")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let lastUpdatedAt = appState.lastUpdatedAt {
                            Text("Updated \(relativeDateFormatter.localizedString(for: lastUpdatedAt, relativeTo: .now))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
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
    }
}

private struct FeedItemRow: View {
    let appState: AppState
    let item: ContentItem

    var body: some View {
        NavigationLink {
            ArticleDetailView(appState: appState, item: item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    FeedItemMetaView(item: item)

                    Text(item.title)
                        .font(.headline)

                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.topics) { topic in
                                Text(topic.title)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let engagement = item.engagement {
                        EngagementSummaryView(engagement: engagement)
                    }
                }

                if let thumbnailURL = item.thumbnailURL {
                    FeedItemThumbnailView(url: thumbnailURL)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct EngagementSummaryView: View {
    let engagement: EngagementMetrics

    var body: some View {
        HStack(spacing: 12) {
            Label(formatted(engagement.reactionCount), systemImage: "arrow.up")
            Label(formatted(engagement.commentCount), systemImage: "bubble.left")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    private func formatted(_ value: Int) -> String {
        if value >= 1000 {
            let thousands = Double(value) / 1000
            return String(format: "%.1fk", thousands)
        }
        return "\(value)"
    }
}

private struct DetailEngagementStat: View {
    let systemImage: String
    let value: Int
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(value)", systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .labelStyle(.titleAndIcon)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct FeedItemMetaView: View {
    let item: ContentItem

    var body: some View {
        HStack(spacing: 8) {
            Label(item.kind.title, systemImage: item.kind.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("•")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(item.sourceName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let linkLabel = externalLinkLabel(for: item) {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(linkLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(relativeDateFormatter.localizedString(for: item.publishedAt, relativeTo: .now))
                .font(.caption)
                .foregroundStyle(.secondary)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Label(item.kind.title, systemImage: item.kind.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Text(item.sourceName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text(relativeDateFormatter.localizedString(for: item.publishedAt, relativeTo: .now))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let authorName = item.authorName {
                            Text("By \(authorName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(item.summary)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }

            if let engagement = item.engagement {
                Section("Community signal") {
                    HStack(spacing: 24) {
                        DetailEngagementStat(systemImage: "arrow.up", value: engagement.reactionCount, caption: "Upvotes")
                        DetailEngagementStat(systemImage: "bubble.left", value: engagement.commentCount, caption: "Comments")
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Topics") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.topics) { topic in
                            Text(topic.title)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            }

            Section("Actions") {
                Button(appState.savedItemIDs.contains(item.id) ? "Remove from saved items" : "Save to saved items") {
                    appState.toggleSaved(itemID: item.id)
                }

                Button {
                    isShowingSourceBrowser = true
                } label: {
                    Label("Read original source", systemImage: "safari")
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
