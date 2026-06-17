import SwiftUI

struct BlockedUsersView: View {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        Group {
            if appState.blockedUserIds.isEmpty {
                ContentUnavailableView(
                    .settingsNoBlockedUsers,
                    systemImage: DSIcon.blockedUsers.rawValue)
            }
            else {
                List {
                    ForEach(Array(appState.blockedUserIds), id: \.self) { userId in
                        HStack {
                            Text(userId)
                                .font(.footnote)
                                .lineLimit(1)
                            Spacer()
                            Button(
                                .settingsUnblock,
                                role: .destructive) {
                                unblockUser(userId)
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationTitle(.settingsBlockedUsers)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func unblockUser(_ userId: String) {
        appState.unblockUser(userId)
    }
}

