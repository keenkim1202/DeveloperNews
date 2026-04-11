import SwiftUI

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter
}()

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        if appState.isOnboardingComplete {
            MainTabView(appState: appState)
        }
        else {
            TopicSelectionView(appState: appState)
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
                                .background(appState.selectedTopics.contains(topic) ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                                .foregroundStyle(appState.selectedTopics.contains(topic) ? Color.accentColor : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Choose at least one topic to continue.")
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

    var body: some View {
        TabView {
            HomeView(appState: appState)
                .tabItem {
                    Label("Home", systemImage: "newspaper")
                }

            SavedView(appState: appState)
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }

            SettingsView(appState: appState)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

private struct HomeView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            List(appState.personalizedItems) { item in
                NavigationLink {
                    ArticleDetailView(appState: appState, item: item)
                } label: {
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
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Trending")
        }
    }
}

private struct SavedView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.savedItems.isEmpty {
                    ContentUnavailableView(
                        "No saved stories yet",
                        systemImage: "bookmark",
                        description: Text("Saved stories will show up here once article detail is wired in.")
                    )
                }
                else {
                    List(appState.savedItems) { item in
                        NavigationLink {
                            ArticleDetailView(appState: appState, item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                FeedItemMetaView(item: item)
                                Text(item.title)
                                    .font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Saved")
        }
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

            Spacer()

            Text(relativeDateFormatter.localizedString(for: item.publishedAt, relativeTo: .now))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsView: View {
    let appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Your topics") {
                    Text("\(appState.selectedTopics.count) selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Topic.allCases) { topic in
                        Button {
                            appState.toggleTopic(topic)
                        } label: {
                            HStack {
                                Label(topic.title, systemImage: topic.symbolName)
                                Spacer()
                                if appState.selectedTopics.contains(topic) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("App") {
                    Button("Reset topic selection", role: .destructive) {
                        appState.resetTopics()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct ArticleDetailView: View {
    let appState: AppState
    let item: ContentItem

    var body: some View {
        List {
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

                Link("Read original source", destination: item.url)
            }
        }
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
    }
}
