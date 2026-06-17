import SwiftUI

struct FeedPostRow: View {
    private let post: FeedPost
    private let currentUserId: String?
    private var onAuthorTap: (() -> Void)?
    private var onLike: (() -> Void)?

    init(
        post: FeedPost,
        currentUserId: String?,
        onAuthorTap: (() -> Void)? = nil,
        onLike: (() -> Void)? = nil,
    ) {
        self.post = post
        self.currentUserId = currentUserId
        self.onAuthorTap = onAuthorTap
        self.onLike = onLike
    }

    private var isLiked: Bool {
        guard let currentUserId else {
            return false
        }
        return post.likedBy.contains(currentUserId)
    }

    @ViewBuilder
    private var authorIcon: some View {
        if let emoji = post.authorEmoji {
            Text(emoji)
                .font(.caption)
        }
        else {
            Image(.unknown)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if !post.comment.isEmpty {
                Text(post.comment)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            NavigationLink(value: CommunityTabDestination.storyDetail(post.story)) {
                quoteCard
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            engagementBar
        }
        .padding(.vertical, 4)
        .background {
            NavigationLink(value: CommunityTabDestination.feedPostDetail(post)) {
                Color.clear
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if let onAuthorTap {
                Button(action: onAuthorTap) {
                    HStack(spacing: 4) {
                        authorIcon
                        Text(post.authorName)
                            .font(.dsLabel)
                            .foregroundStyle(DSColor.accent)
                            .underline()
                    }
                }
                .buttonStyle(.plain)
            }
            else {
                authorIcon
                Text(post.authorName)
                    .font(.dsLabel)
            }
            Text("·")
                .foregroundStyle(.tertiary)
            Text(relativeDateFormatter.localizedString(for: post.createdAt, relativeTo: .now))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var quoteCard: some View {
        HStack(alignment: .top, spacing: 12) {
            if let thumbnailURL = post.story.thumbnailURL.flatMap(URL.init(string:)) {
                FeedPostRowThumbnail(url: thumbnailURL)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(post.story.title)
                    .font(.dsCardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Text(post.story.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            DSColor.surface
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var engagementBar: some View {
        HStack(spacing: 16) {
            Button(action: like) {
                HStack(spacing: 4) {
                    Image(isLiked ? .likeFilled : .like)
                        .foregroundStyle(isLiked ? .red : .secondary)
                    Text("\(post.likeCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(onLike == nil)

            HStack(spacing: 4) {
                Image(.comment)
                Text("\(post.commentCount)")
            }
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func like() {
        onLike?()
    }
}


private struct FeedPostRowThumbnail: View {
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
                    .overlay {
                        ProgressView().controlSize(.small)
                    }
            @unknown default:
                DSColor.fill
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
