import SwiftUI

struct UserSearchView: View {
    private let appState: AppState

    @State private var viewModel: UserSearchViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: UserSearchViewModel(appState: appState))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            content
        }
        .navigationTitle(Text(.userSearchTitle))
        .navigationBarTitleDisplayMode(.inline)
        .keenOnChange(of: viewModel.query, perform: onQueryChange)
        .toolbar(.hidden, for: .tabBar)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(text: $viewModel.query) {
                Text(.userSearchPlaceholder)
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DSColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        else if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView {
                Label(.userSearchTitle, icon: .community)
            } description: {
                Text(.userSearchEmpty)
            }
        }
        else if viewModel.results.isEmpty {
            ContentUnavailableView {
                Label(.userSearchNoResults, icon: .community)
            }
        }
        else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.results) { summary in
                    row(for: summary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for summary: UserSummary) -> some View {
        HStack(spacing: 12) {
            NavigationLink(
                value: CommunityTabDestination.userProfile(userId: summary.id)
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

    private func onQueryChange() {
        viewModel.queryChanged()
    }

    private func toggleFollow(_ summary: UserSummary) {
        Task {
            await viewModel.toggleFollow(summary.id)
        }
    }
}
