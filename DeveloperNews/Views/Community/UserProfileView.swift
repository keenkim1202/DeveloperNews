import SwiftUI

struct UserProfileView: View {
    let appState: AppState
    let authorId: String
    let authorName: String
    let authorEmoji: String?

    @State private var followerCount = 0
    @State private var followingCount = 0

    private var currentUserId: String? { appState.authService.userId }
    private var isOwnProfile: Bool { currentUserId == authorId }
    private var isFollowingAuthor: Bool { appState.profileService.isFollowing(authorId) }

    private var authorPosts: [CommunityPost] {
        appState.communityService.posts.filter { $0.authorId == authorId }
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
                            Text("\(authorPosts.count)")
                                .font(.headline)
                            Text(.profilePosts)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(followerCount)")
                                .font(.headline)
                            Text(.profileFollowers)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(followingCount)")
                                .font(.headline)
                            Text(.communityFollowing)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            let totalLikes = authorPosts.reduce(0) { $0 + $1.likeCount }
                            Text("\(totalLikes)")
                                .font(.headline)
                            Text(.profileLikes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !isOwnProfile, currentUserId != nil {
                        Button(action: toggleFollow) {
                            Text(isFollowingAuthor ? .communityFollowing : .communityFollow)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 120, height: 34)
                                .background(
                                    isFollowingAuthor
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground))
                                .foregroundStyle(
                                    isFollowingAuthor
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

                if authorPosts.isEmpty {
                    Text(.profileNoPosts)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
                else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(authorPosts) { post in
                            NavigationLink {
                                CommunityPostDetailView(appState: appState, post: post)
                            } label: {
                                CommunityPostRow(appState: appState, post: post, authorEmoji: authorEmoji)
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
        .task {
            followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
            followingCount = await appState.profileService.fetchFollowingCount(for: authorId)
        }
    }

    private func toggleFollow() {
        Task {
            await appState.profileService.toggleFollow(authorId)
            followerCount = await appState.profileService.fetchFollowerCount(for: authorId)
        }
    }
}

