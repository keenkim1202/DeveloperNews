import Foundation
import Observation

@Observable
@MainActor
final class UserSearchViewModel {
    private let appState: AppState

    var query = ""
    var results: [UserSummary] = []
    var isLoading = false

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    var currentUserId: String? {
        appState.authService.userId
    }

    func isFollowing(_ summaryId: String) -> Bool {
        appState.profileService.isFollowing(summaryId)
    }

    // Debounce keystrokes: cancel any in-flight search, wait 300ms, then run.
    // Bails out early if the task was cancelled by a newer keystroke.
    func queryChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled {
                return
            }
            await search()
        }
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isLoading = true
        results = await appState.profileService.searchUsers(matching: trimmed)
        isLoading = false
        if let message = appState.profileService.errorMessage {
            appState.presentError(message)
        }
    }

    func toggleFollow(_ summaryId: String) async {
        await appState.profileService.toggleFollow(summaryId)
        if let message = appState.profileService.errorMessage {
            appState.presentError(message)
        }
    }
}
