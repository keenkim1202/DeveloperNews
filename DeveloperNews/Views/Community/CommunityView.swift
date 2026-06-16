import SwiftUI

struct CommunityView: View {
    private let appState: AppState

    @Bindable private var viewModel: CommunityViewModel
    @Bindable private var navigation: Navigation

    init(
        appState: AppState,
        viewModel: CommunityViewModel,
        navigation: Navigation,
    ) {
        self.appState = appState
        self.viewModel = viewModel
        self.navigation = navigation
    }

    var body: some View {
        NavigationStack(path: $navigation.community) {
            ScrollViewReader { proxy in
                content
                    .keenOnChange(of: viewModel.scrollToTopTrigger) {
                        guard let anchor = viewModel.firstPostId else { return }
                        withAnimation {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                    }
            }
            .navigationTitle(.community)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: .communitySearchPrompt)
            .toolbar {
                if viewModel.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: openCreatePost) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationDestination(for: CommunityTabDestination.self, destination: destination)
            .sheet(isPresented: $viewModel.showCreatePost) {
                CreatePostView(appState: appState)
            }
        }
    }

    @ViewBuilder
    private func destination(_ dest: CommunityTabDestination) -> some View {
        switch dest {
        case let .postDetail(postId):
            if let post = appState.communityService.post(id: postId) {
                CommunityPostDetailView(appState: appState, post: post)
            }
            else {
                UnavailableDestinationView(reason: .postDeleted)
            }
        case let .userProfile(author):
            UserProfileView(
                appState: appState,
                authorId: author.id,
                authorName: author.name,
                authorEmoji: author.emoji)
        case let .postLinkDetail(postId):
            if let post = appState.communityService.post(id: postId),
               let item = postLinkItem(for: post) {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        }
    }

    private func postLinkItem(for post: CommunityPost) -> ContentItem? {
        guard post.hasLink,
              let url = post.linkURL
        else {
            return nil
        }
        return ContentItem(
            id: UUID(),
            kind: .article,
            title: post.title,
            summary: "",
            sourceName: post.authorName,
            sourceCategory: .article,
            authorName: post.authorName,
            url: url,
            publishedAt: post.createdAt,
            topics: post.topics,
            trendScore: 0)
    }

    private func navigateToProfile(_ author: AuthorInfo) {
        navigation(.community(.userProfile(author)))
    }

    private func openCreatePost() {
        viewModel.showCreatePost = true
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingPosts && viewModel.hasNoPosts {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if viewModel.hasNoPosts {
            ContentUnavailableView {
                Label(.communityEmpty, systemImage: "person.2")
            } description: {
                Text(.communityEmptyDescription)
            }
        }
        else {
            List {
                ForEach(viewModel.filteredPosts) { post in
                    let emoji = appState.communityService.authorEmoji(for: post.authorId)
                    NavigationLink(value: CommunityTabDestination.postDetail(post.id)) {
                        CommunityPostRow(
                            appState: appState,
                            post: post,
                            authorEmoji: emoji) {
                            navigateToProfile(
                                AuthorInfo(
                                    id: post.authorId,
                                    name: post.authorName,
                                    emoji: emoji))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable(action: refresh)
        }
    }

    private func refresh() async {
        await viewModel.refresh()
    }
}


struct CommunityPostRow: View {
    private let appState: AppState
    private let post: CommunityPost
    private var authorEmoji: String?
    private var onAuthorTap: (() -> Void)?

    init(
        appState: AppState,
        post: CommunityPost,
        authorEmoji: String? = nil,
        onAuthorTap: (() -> Void)? = nil,
    ) {
        self.appState = appState
        self.post = post
        self.authorEmoji = authorEmoji
        self.onAuthorTap = onAuthorTap
    }

    private var currentUserId: String? {
        appState.authService.userId
    }
    private var isLiked: Bool {
        guard let uid = currentUserId else { return false }
        return post.likedBy.contains(uid)
    }

    @ViewBuilder
    private var authorIcon: some View {
        if let authorEmoji {
            Text(authorEmoji)
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
                    Button(action: onAuthorTap) {
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
                            .background {
                                Color(.secondarySystemBackground)
                            }
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .secondary)
                    Text("\(post.likeCount)")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(post.commentCount)")
                }
                .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
