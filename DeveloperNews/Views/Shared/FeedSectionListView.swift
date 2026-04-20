import SwiftUI

struct FeedSectionListView: View {
    private let appState: AppState
    private let articleItems: [ContentItem]
    private let discussionItems: [ContentItem]

    private var showsSummary: Bool
    private var hasMore: Bool
    private var onLoadMore: (() -> Void)?
    private var scrollToTopTrigger: Int
    private var topContent: AnyView?

    @State private var selectedAuthor: AuthorInfo?

    init(
        appState: AppState,
        articleItems: [ContentItem],
        discussionItems: [ContentItem],
        showsSummary: Bool = true,
        hasMore: Bool = false,
        onLoadMore: (() -> Void)? = nil,
        scrollToTopTrigger: Int = 0,
        topContent: AnyView? = nil,
    ) {
        self.appState = appState
        self.articleItems = articleItems
        self.discussionItems = discussionItems
        self.showsSummary = showsSummary
        self.hasMore = hasMore
        self.onLoadMore = onLoadMore
        self.scrollToTopTrigger = scrollToTopTrigger
        self.topContent = topContent
    }

    private var firstAnchorID: ContentItem.ID? {
        articleItems.first?.id ?? discussionItems.first?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            list
                .keenOnChange(of: scrollToTopTrigger) {
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
                authorEmoji: author.emoji)
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
                        FeedItemRow(
                            appState: appState,
                            item: item,
                            selectedAuthor: $selectedAuthor)
                    }
                }
            }

            if !discussionItems.isEmpty {
                Section(.discussions) {
                    ForEach(discussionItems) { item in
                        FeedItemRow(
                            appState: appState,
                            item: item,
                            selectedAuthor: $selectedAuthor)
                    }
                }
            }

            if hasMore,
               let onLoadMore {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text(.loadingMore)
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


struct AuthorInfo: Hashable {
    let id: String
    let name: String
    let emoji: String?
}

