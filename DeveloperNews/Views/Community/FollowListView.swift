import SwiftUI

struct FollowListView: View {
    private let appState: AppState

    @State private var viewModel: FollowListViewModel

    init(
        appState: AppState,
        userId: String,
        kind: FollowListKind,
    ) {
        self.appState = appState
        _viewModel = State(initialValue: FollowListViewModel(
            appState: appState,
            userId: userId,
            kind: kind))
    }

    private var title: LocalizedStringResource {
        switch viewModel.kind {
        case .followers:
            .profileFollowers
        case .following:
            .communityFollowing
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else if viewModel.summaries.isEmpty {
                Text(.profileFollowListEmpty)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.summaries) { summary in
                            row(for: summary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(load)
    }

    @ViewBuilder
    private func row(for summary: UserSummary) -> some View {
        HStack(spacing: 12) {
            NavigationLink(
                value: CommunityTabDestination.userProfile(
                    AuthorInfo(
                        id: summary.id,
                        name: summary.displayName,
                        emoji: summary.emoji))
            ) {
                HStack(spacing: 12) {
                    avatar(for: summary)
                    Text(summary.displayName)
                        .font(.dsCardTitle)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            if summary.id != viewModel.currentUserId {
                FollowButton(
                    isFollowing: viewModel.isFollowing(summary.id),
                    action: { toggleFollow(summary) })
            }
        }
    }

    @ViewBuilder
    private func avatar(for summary: UserSummary) -> some View {
        Group {
            if let emoji = summary.emoji {
                Text(emoji)
                    .font(.title3)
            }
            else {
                Image(.unknown)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .background(DSColor.surface)
        .clipShape(Circle())
    }

    private func load() async {
        await viewModel.load()
    }

    private func toggleFollow(_ summary: UserSummary) {
        Task {
            await viewModel.toggleFollow(summary.id)
        }
    }
}
