import SwiftUI

struct FeedSectionListView<Destination: Hashable>: View {
    private let translator: any Translating
    private let lastUpdatedAt: Date?
    private let isRead: (ContentItem) -> Bool
    private let followingPost: (ContentItem) -> CommunityPost?
    private let authorEmoji: (String) -> String?
    private let articleItems: [ContentItem]
    private let discussionItems: [ContentItem]
    private let destinationFor: (ContentItem) -> Destination
    private let onAuthorTap: (String) -> Void
    private let inAppEngagement: (ContentItem) -> StoryEngagement?

    private var showsSummary: Bool
    private var hasMore: Bool
    private var onLoadMore: (() -> Void)?
    private var scrollToTopTrigger: Int
    private var topContent: AnyView?

    init(
        translator: any Translating,
        lastUpdatedAt: Date?,
        isRead: @escaping (ContentItem) -> Bool,
        followingPost: @escaping (ContentItem) -> CommunityPost?,
        authorEmoji: @escaping (String) -> String?,
        articleItems: [ContentItem],
        discussionItems: [ContentItem],
        destinationFor: @escaping (ContentItem) -> Destination,
        onAuthorTap: @escaping (String) -> Void,
        inAppEngagement: @escaping (ContentItem) -> StoryEngagement? = { _ in nil },
        showsSummary: Bool = true,
        hasMore: Bool = false,
        onLoadMore: (() -> Void)? = nil,
        scrollToTopTrigger: Int = 0,
        topContent: AnyView? = nil,
    ) {
        self.translator = translator
        self.lastUpdatedAt = lastUpdatedAt
        self.isRead = isRead
        self.followingPost = followingPost
        self.authorEmoji = authorEmoji
        self.articleItems = articleItems
        self.discussionItems = discussionItems
        self.destinationFor = destinationFor
        self.onAuthorTap = onAuthorTap
        self.inAppEngagement = inAppEngagement
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

                        if let lastUpdatedAt {
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
                            translator: translator,
                            item: item,
                            destination: destinationFor(item),
                            isRead: isRead(item),
                            followingPost: followingPost(item),
                            authorEmoji: authorEmoji,
                            onAuthorTap: onAuthorTap,
                            storyEngagement: inAppEngagement(item))
                    }
                }
            }

            if !discussionItems.isEmpty {
                Section(.discussions) {
                    ForEach(discussionItems) { item in
                        FeedItemRow(
                            translator: translator,
                            item: item,
                            destination: destinationFor(item),
                            isRead: isRead(item),
                            followingPost: followingPost(item),
                            authorEmoji: authorEmoji,
                            onAuthorTap: onAuthorTap,
                            storyEngagement: inAppEngagement(item))
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

