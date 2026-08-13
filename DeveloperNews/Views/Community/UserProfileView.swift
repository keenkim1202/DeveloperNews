import SwiftUI

struct UserProfileView: View {
    private let appState: AppState
    private let providedAuthorName: String?
    private let providedAuthorEmoji: String?

    @State private var viewModel: UserProfileViewModel
    @State private var showBlockConfirm = false

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        authorId: String,
    ) {
        self.appState = appState
        self.providedAuthorName = nil
        self.providedAuthorEmoji = nil
        _viewModel = State(initialValue: UserProfileViewModel(
            appState: appState,
            authorId: authorId))
    }

    // Kept for call sites whose navigation destination still carries the name and emoji.
    init(
        appState: AppState,
        authorId: String,
        authorName: String,
        authorEmoji: String?,
    ) {
        self.appState = appState
        self.providedAuthorName = authorName
        self.providedAuthorEmoji = authorEmoji
        _viewModel = State(initialValue: UserProfileViewModel(
            appState: appState,
            authorId: authorId))
    }

    private var displayName: String {
        if let providedAuthorName {
            return providedAuthorName
        }
        if let loadedName = viewModel.authorName {
            return loadedName
        }
        // Blank until both identity sources have been tried, so the title does
        // not read "Unknown user" for the length of a fetch and then change
        // under the reader.
        return viewModel.hasResolvedIdentity ? String(localized: .settingsUnknownUser) : ""
    }

    private var displayEmoji: String? {
        providedAuthorEmoji ?? viewModel.authorEmoji
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    if let displayEmoji {
                        Text(displayEmoji)
                            .font(.system(size: 60))
                    }
                    else {
                        Image(.unknown)
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                    }

                    Text(displayName)
                        .font(.title3.bold())
                    if let bio = viewModel.authorBio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .padding(.horizontal, 24)
                    }
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(viewModel.authorFeedPosts.count)")
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

                if viewModel.authorFeedPosts.isEmpty {
                    Text(.profileNoPosts)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
                else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.authorFeedPosts) { post in
                            FeedPostRow(
                                post: post,
                                currentUserId: appState.authService.userId)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .navigationTitle(displayName)
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
        .task(loadFeedPosts)
        .task(loadBio)
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

    private func loadFeedPosts() async {
        await viewModel.loadFeedPosts()
    }

    private func loadBio() async {
        await viewModel.loadBio()
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

