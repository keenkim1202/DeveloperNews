import Foundation
import Observation

@Observable
@MainActor
final class CommunityViewModel {
    private let appState: AppState

    var searchQuery = ""
    var showCreatePost = false
    var selectedAuthor: AuthorInfo?

    init(appState: AppState) {
        self.appState = appState
    }

    var isSignedIn: Bool { appState.authService.isSignedIn }
    var scrollToTopTrigger: Int { appState.communityScrollToTopTrigger }
    var isLoadingPosts: Bool { appState.communityService.isLoading }
    var hasNoPosts: Bool { appState.communityService.posts.isEmpty }
    var firstPostId: String? { appState.communityService.posts.first?.id }

    var filteredPosts: [CommunityPost] {
        let posts = appState.communityService.filteredPosts(excludingUserIds: appState.blockedUserIds)
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return posts }
        let needle = query.lowercased()
        return posts.filter {
            $0.title.lowercased().contains(needle) ||
            $0.description.lowercased().contains(needle) ||
            $0.authorName.lowercased().contains(needle)
        }
    }

    func refresh() async {
        await appState.communityService.refresh()
    }
}
