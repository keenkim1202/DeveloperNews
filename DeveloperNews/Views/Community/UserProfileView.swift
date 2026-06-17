import SwiftUI

struct UserProfileView: View {
    private let appState: AppState
    private let authorName: String
    private let authorEmoji: String?

    @State private var viewModel: UserProfileViewModel
    @State private var showBlockConfirm = false

    @Environment(\.dismiss) private var dismiss

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
                        Image(.unknown)
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
                        NavigationLink(value: followListDestination(.followers)) {
                            VStack {
                                Text("\(viewModel.followerCount)")
                                    .font(.headline)
                                Text(.profileFollowers)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: followListDestination(.following)) {
                            VStack {
                                Text("\(viewModel.followingCount)")
                                    .font(.headline)
                                Text(.communityFollowing)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !viewModel.isOwnProfile, viewModel.currentUserId != nil {
                        FollowButton(
                            isFollowing: viewModel.isFollowingAuthor,
                            action: toggleFollow)
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
        .toolbar {
            if !viewModel.isOwnProfile, viewModel.currentUserId != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(
                            .communityBlockUser,
                            role: .destructive,
                            action: confirmBlockUser)
                    } label: {
                        Image(.more)
                    }
                }
            }
        }
        .task(loadFollowCounts)
        .alert(
            .communityBlockConfirmTitle,
            isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button(
                .communityBlockConfirmAction,
                role: .destructive,
                action: blockUser)
        } message: {
            Text(.communityBlockConfirmMessage)
        }
    }

    private func followListDestination(_ kind: FollowListKind) -> CommunityTabDestination {
        .followList(FollowListTarget(userId: viewModel.authorId, kind: kind))
    }

    private func loadFollowCounts() async {
        await viewModel.loadFollowCounts()
    }

    private func toggleFollow() {
        Task {
            await viewModel.toggleFollow()
        }
    }

    private func confirmBlockUser() {
        showBlockConfirm = true
    }

    private func blockUser() {
        viewModel.blockAuthor()
        dismiss()
    }
}

