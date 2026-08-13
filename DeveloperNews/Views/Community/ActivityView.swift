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
        .task(load)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.activities) { activity in
                    row(for: activity)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func row(for activity: Activity) -> some View {
        if let destination = viewModel.destination(for: activity) {
            NavigationLink(value: destination) {
                ActivityRow(
                    activity: activity,
                    actor: viewModel.actor(for: activity),
                    isUnread: viewModel.isUnread(activity))
            }
            .buttonStyle(.plain)
        }
        else {
            ActivityRow(
                activity: activity,
                actor: viewModel.actor(for: activity),
                isUnread: viewModel.isUnread(activity))
        }
    }

    private func load() async {
        await viewModel.onAppear()
    }
}
