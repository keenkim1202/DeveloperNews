import SwiftUI

@available(*, deprecated, message: "Replaced by Community2View")
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
                            Image(.add)
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
        case let .userProfile(userId):
            UserProfileView(appState: appState, authorId: userId)
        case let .postLinkDetail(postId):
            if let post = appState.communityService.post(id: postId),
               let item = post.linkContentItem {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .followList(target):
            FollowListView(
                appState: appState,
                userId: target.userId,
                kind: target.kind)
        case let .storyDetail(story):
            if let item = story.contentItem {
                ArticleDetailView(appState: appState, item: item)
            }
            else {
                UnavailableDestinationView(reason: .itemNotFound)
            }
        case let .feedPostDetail(post):
            FeedPostDetailView(appState: appState, post: post)
        case .userSearch:
            UserSearchView(appState: appState)
        }
    }

    private func navigateToProfile(userId: String) {
        navigation(.community(.userProfile(userId: userId)))
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
                Label(.communityEmpty, icon: .community)
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
                            currentUserId: appState.authService.userId,
                            isRead: appState.isPostRead(post.id),
                            post: post,
                            authorEmoji: emoji) {
                            navigateToProfile(userId: post.authorId)
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


@available(*, deprecated, message: "Replaced by Community2View")
struct CommunityPostRow: View {
    private let currentUserId: String?
    private let isRead: Bool
    private let post: CommunityPost
    private var authorEmoji: String?
    private var onAuthorTap: (() -> Void)?

    init(
        currentUserId: String?,
        isRead: Bool,
        post: CommunityPost,
        authorEmoji: String? = nil,
        onAuthorTap: (() -> Void)? = nil,
    ) {
        self.currentUserId = currentUserId
        self.isRead = isRead
        self.post = post
        self.authorEmoji = authorEmoji
        self.onAuthorTap = onAuthorTap
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
            Image(.unknown)
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

            Text(post.title)
                .font(.dsCardTitle)
                .foregroundStyle(isRead ? .secondary : .primary)
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
                                DSColor.surface
                            }
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(isLiked ? .likeFilled : .like)
                        .foregroundStyle(isLiked ? .red : .secondary)
                    Text("\(post.likeCount)")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(.comment)
                    Text("\(post.commentCount)")
                }
                .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
