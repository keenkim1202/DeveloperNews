import SwiftUI

struct BlockedUsersView: View {
    let appState: AppState

    var body: some View {
        Group {
            if appState.blockedUserIds.isEmpty {
                ContentUnavailableView("settings.noBlockedUsers", systemImage: "person.slash")
            }
            else {
                List {
                    ForEach(Array(appState.blockedUserIds), id: \.self) { userId in
                        HStack {
                            Text(userId)
                                .font(.footnote)
                                .lineLimit(1)
                            Spacer()
                            Button("settings.unblock", role: .destructive) {
                                appState.unblockUser(userId)
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.blockedUsers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

