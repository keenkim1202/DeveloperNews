import SwiftUI

struct BlockedUsersView: View {
    private let appState: AppState

    @State private var summaries: [String: UserSummary] = [:]

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
                        blockedUserRow(userId)
                    }
                }
            }
        }
        .navigationTitle(.settingsBlockedUsers)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(loadSummaries)
    }

    @ViewBuilder
    private func blockedUserRow(_ userId: String) -> some View {
        HStack(spacing: 8) {
            userIcon(for: userId)
            Text(displayName(for: userId))
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

    @ViewBuilder
    private func userIcon(for userId: String) -> some View {
        if let emoji = summaries[userId]?.emoji {
            Text(emoji)
                .font(.footnote)
        }
        else {
            Image(.unknown)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func displayName(for userId: String) -> String {
        if let name = summaries[userId]?.displayName {
            return name
        }
        return String(localized: .settingsUnknownUser)
    }

    private func loadSummaries() async {
        let fetched = await appState.profileService.fetchUserSummaries(
            for: Array(appState.blockedUserIds))
        summaries = Dictionary(
            uniqueKeysWithValues: fetched.map { ($0.id, $0) })
    }

    private func unblockUser(_ userId: String) {
        appState.unblockUser(userId)
    }
}
