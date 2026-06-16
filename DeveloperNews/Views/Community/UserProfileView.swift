import SwiftUI

struct UserProfileView: View {
    private let appState: AppState
    private let authorName: String
    private let authorEmoji: String?

    @State private var viewModel: UserProfileViewModel

    init(
        appState: AppState,
        authorId: String,
        authorName: String,
        authorEmoji: String?,
    ) {
        self.appState = appState
        self.authorName = authorName
        self.authorEmoji = authorEmoji
        _viewModel = State(initialValue: UserProfileViewModel(
            appState: appState,
            authorId: authorId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    if let authorEmoji {
                        Text(authorEmoji)
                            .font(.system(size: 60))
                    }
                    else {
                        Image(systemName: "questionmark.circle.dashed")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                    }

                    Text(authorName)
                        .font(.title3.bold())
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(viewModel.authorPosts.count)")
                                .font(.headline)
                            Text(.profilePosts)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(viewModel.followerCount)")
                                .font(.headline)
                            Text(.profileFollowers)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(viewModel.followingCount)")
                                .font(.headline)
                            Text(.communityFollowing)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            let totalLikes = viewModel.authorPosts.reduce(0) { $0 + $1.likeCount }
                            Text("\(totalLikes)")
                                .font(.headline)
                            Text(.profileLikes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !viewModel.isOwnProfile, viewModel.currentUserId != nil {
                        Button(action: toggleFollow) {
                            Text(viewModel.isFollowingAuthor ? .communityFollowing : .communityFollow)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 120, height: 34)
                                .background {
                                    viewModel.isFollowingAuthor
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                }
                                .foregroundStyle(
                                    viewModel.isFollowingAuthor
                                        ? Color.white
                                        : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 20)

                if viewModel.authorPosts.isEmpty {
                    Text(.profileNoPosts)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
                else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.authorPosts) { post in
                            NavigationLink(value: CommunityTabDestination.postDetail(post.id)) {
                                CommunityPostRow(
                                    currentUserId: appState.authService.userId,
                                    isRead: appState.isPostRead(post.id),
                                    post: post,
                                    authorEmoji: authorEmoji)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(loadFollowCounts)
    }

    private func loadFollowCounts() async {
        await viewModel.loadFollowCounts()
    }

    private func toggleFollow() {
        Task {
            await viewModel.toggleFollow()
        }
    }
}

