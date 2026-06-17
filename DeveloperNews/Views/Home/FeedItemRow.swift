import SwiftUI
import Translation

struct FeedItemRow<Destination: Hashable>: View {
    private let translator: any Translating
    private let item: ContentItem
    private let destination: Destination
    private let isRead: Bool
    private let followingPost: CommunityPost?
    private let authorEmoji: (String) -> String?
    private let onAuthorTap: (AuthorInfo) -> Void
    private let storyEngagement: StoryEngagement?

    @State private var translationTrigger = 0
    @State private var showingTranslation = false

    init(
        translator: any Translating,
        item: ContentItem,
        destination: Destination,
        isRead: Bool,
        followingPost: CommunityPost?,
        authorEmoji: @escaping (String) -> String?,
        onAuthorTap: @escaping (AuthorInfo) -> Void,
        storyEngagement: StoryEngagement? = nil,
    ) {
        self.translator = translator
        self.item = item
        self.destination = destination
        self.isRead = isRead
        self.followingPost = followingPost
        self.authorEmoji = authorEmoji
        self.onAuthorTap = onAuthorTap
        self.storyEngagement = storyEngagement
    }

    private var displayTitle: String {
        showingTranslation ? translator.title(for: item) : item.title
    }

    private var displaySummary: String {
        showingTranslation ? translator.summary(for: item) : item.summary
    }

    var body: some View {
        NavigationLink(value: destination) {
            VStack(alignment: .leading, spacing: 8) {
                FeedItemMetaView(
                    item: item,
                    authorEmoji: followingPost.flatMap {
                        authorEmoji($0.authorId)
                    }) {
                    guard let post = followingPost else { return }
                    onAuthorTap(
                        AuthorInfo(
                            id: post.authorId,
                            name: post.authorName,
                            emoji: authorEmoji(post.authorId)))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundStyle(isRead ? .secondary : .primary)
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
                                    .font(.dsTag)
                                    .foregroundStyle(DSColor.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background {
                                        DSColor.accent.opacity(0.15)
                                    }
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
                            Image(.translate)
                            Text(showingTranslation ? .translationShowOriginal : .translationShowTranslated)
                        }
                        .font(.dsTag)
                        .foregroundStyle(showingTranslation ? DSColor.accent : Color.primary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    if let storyEngagement {
                        InAppEngagementSummaryView(engagement: storyEngagement)
                    }
                    else if let engagement = item.engagement {
                        EngagementSummaryView(engagement: engagement)
                    }
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
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                DSColor.fill
                    .overlay {
                        Image(.photo)
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                DSColor.fill
                    .overlay { ProgressView().controlSize(.small) }
            @unknown default:
                DSColor.fill
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}


struct FeedItemMetaView: View {
    private let item: ContentItem
    private var authorEmoji: String?
    private var onAuthorTap: (() -> Void)?

    init(
        item: ContentItem,
        authorEmoji: String? = nil,
        onAuthorTap: (() -> Void)? = nil,
    ) {
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
                                Image(.unknown)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.sourceName)
                                .font(.dsLabel)
                                .foregroundStyle(DSColor.accent)
                                .underline()
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .buttonStyle(.plain)
                }
                else {
                    Text(item.sourceName)
                        .font(.dsLabel)
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

