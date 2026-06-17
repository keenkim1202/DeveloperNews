import SwiftUI

struct FollowListView: View {
    private let appState: AppState

    @State private var viewModel: FollowListViewModel

    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
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
                    List(viewModel.summaries) { summary in
                        row(for: summary)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.commonDone, action: close)
                }
            }
            .task(load)
        }
    }

    @ViewBuilder
    private func row(for summary: UserSummary) -> some View {
        HStack(spacing: 12) {
            icon(for: summary)
            Text(summary.displayName)
                .font(.body)
            Spacer()
            if summary.id != viewModel.currentUserId {
                followControl(for: summary)
            }
        }
    }

    @ViewBuilder
    private func icon(for summary: UserSummary) -> some View {
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

    private func followControl(for summary: UserSummary) -> some View {
        let isFollowing = viewModel.isFollowing(summary.id)
        return Button {
            toggleFollow(summary)
        } label: {
            Text(isFollowing ? .communityFollowing : .communityFollow)
                .font(.dsCardTitle)
                .frame(width: 100, height: 30)
                .background {
                    isFollowing
                        ? DSColor.accent
                        : DSColor.surface
                }
                .foregroundStyle(
                    isFollowing
                        ? DSColor.onAccent
                        : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        await viewModel.load()
    }

    private func toggleFollow(_ summary: UserSummary) {
        Task {
            await viewModel.toggleFollow(summary.id)
        }
    }

    private func close() {
        dismiss()
    }
}
