import SwiftUI

struct CommunityView: View {
    let appState: AppState
    @State private var viewModel: CommunityViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: CommunityViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
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
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: .communitySearchPrompt)
            .toolbar {
                if viewModel.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: openCreatePost) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreatePost) {
                CreatePostView(appState: appState)
            }
        }
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
                    NavigationLink {
                        CommunityPostDetailView(appState: appState, post: post)
                    } label: {
                        CommunityPostRow(appState: appState, post: post, authorEmoji: emoji) {
                            viewModel.selectedAuthor = AuthorInfo(
                                id: post.authorId,
                                name: post.authorName,
                                emoji: emoji)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(item: $viewModel.selectedAuthor) { author in
                UserProfileView(appState: appState, authorId: author.id, authorName: author.name, authorEmoji: author.emoji)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}


struct CommunityPostRow: View {
    let appState: AppState
    let post: CommunityPost
    var authorEmoji: String?
    var onAuthorTap: (() -> Void)?

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
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? .red : .secondary)
                Text("\(post.likeCount)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
