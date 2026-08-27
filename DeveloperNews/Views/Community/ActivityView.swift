import SwiftUI

struct ActivityView: View {
    private let appState: AppState

    @State private var viewModel: ActivityViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: ActivityViewModel(appState: appState))
    }

    var body: some View {
        Group {
            if !viewModel.isSignedIn {
                ContentUnavailableView {
                    Label(.activitySignIn, icon: .account)
                } description: {
                    Text(.activitySignInDescription)
                }
            }
            else if viewModel.isEmpty {
                ContentUnavailableView {
                    Label(.activityEmpty, icon: .emptyTray)
                } description: {
                    Text(.activityEmptyDescription)
                }
            }
            else {
                list
            }
        }
        .navigationTitle(.activityTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .keenOnChange(of: viewModel.activities, perform: onActivitiesChange)
        .task(load)
    }

    // A List rather than the scrolling stack the other screens use: swipe to
    // delete is a list row behaviour, and dismissing one notification is the
    // reason this screen needs it.
    private var list: some View {
        List {
            ForEach(viewModel.activities) { activity in
                row(for: activity)
                    .listRowInsets(EdgeInsets())
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(activity)
                        } label: {
                            Label(.activityDelete, icon: .delete)
                        }
                    }
            }

            if viewModel.canLoadMore {
                loadMoreRow
            }
        }
        .listStyle(.plain)
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text(.loadingMore)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .onAppear(perform: loadMore)
    }

    @ViewBuilder
    private func row(for activity: Activity) -> some View {
        if let destination = ActivityViewModel.destination(for: activity) {
            NavigationLink(value: destination) {
                ActivityRow(
                    activity: activity,
                    actor: viewModel.actor(for: activity),
                    isUnread: viewModel.isUnread(activity))
            }
        }
        else {
            ActivityRow(
                activity: activity,
                actor: viewModel.actor(for: activity),
                isUnread: viewModel.isUnread(activity))
        }
    }

    private func load() async {
        await viewModel.sync()
    }

    private func onActivitiesChange() {
        Task {
            await viewModel.sync()
        }
    }

    private func loadMore() {
        viewModel.loadMore()
    }

    private func delete(_ activity: Activity) {
        Task {
            await viewModel.delete(activity)
        }
    }
}
