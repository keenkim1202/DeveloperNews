import SwiftUI
import Translation

struct FeedItemRow: View {
    private let appState: AppState
    private let item: ContentItem
    private var selectedAuthor: Binding<AuthorInfo?>

    @State private var translationTrigger = 0
    @State private var showingTranslation = false

    init(
        appState: AppState,
        item: ContentItem,
        selectedAuthor: Binding<AuthorInfo?>,
    ) {
        self.appState = appState
        self.item = item
        self.selectedAuthor = selectedAuthor
    }

    private var translator: ContentTranslator {
        appState.translator
    }

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
            if let post = followingPost {
                CommunityPostDetailView(
                    appState: appState,
                    post: post)
            }
            else if item.isUserCreated {
                BookmarkDetailView(
                    appState: appState,
                    item: item)
            }
            else {
                ArticleDetailView(
                    appState: appState,
                    item: item)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                FeedItemMetaView(
                    appState: appState,
                    item: item,
                    authorEmoji: followingPost.flatMap {
                        appState.communityService.authorEmoji(for: $0.authorId)
                    }) {
                    guard let post = followingPost else { return }
                    selectedAuthor.wrappedValue = AuthorInfo(
                        id: post.authorId,
                        name: post.authorName,
                        emoji: appState.communityService.authorEmoji(for: post.authorId))
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
                    Button(action: toggleTranslation) {
                        HStack(spacing: 2) {
                            Image(systemName: "translate")
                            Text(showingTranslation ? .translationShowOriginal : .translationShowTranslated)
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

    private func toggleTranslation() {
        if translator.isTranslated(item) {
            showingTranslation.toggle()
        }
        else {
            translationTrigger &+= 1
        }
    }
}


struct FeedItemThumbnailView: View {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

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


struct FeedItemMetaView: View {
    private let appState: AppState
    private let item: ContentItem
    private var authorEmoji: String?
    private var onAuthorTap: (() -> Void)?

    init(
        appState: AppState,
        item: ContentItem,
        authorEmoji: String? = nil,
        onAuthorTap: (() -> Void)? = nil,
    ) {
        self.appState = appState
        self.item = item
        self.authorEmoji = authorEmoji
        self.onAuthorTap = onAuthorTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if item.sourceCategory != .following {
                    Image(systemName: item.kind.symbolName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if item.sourceCategory == .following,
                   let onAuthorTap {
                    Button(action: onAuthorTap) {
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

