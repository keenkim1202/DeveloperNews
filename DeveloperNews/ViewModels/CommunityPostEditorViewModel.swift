import Foundation
import Observation

@Observable
@MainActor
final class CommunityPostEditorViewModel {
    private let appState: AppState
    private let existingPost: CommunityPost?

    init(
        appState: AppState,
        existingPost: CommunityPost?,
    ) {
        self.appState = appState
        self.existingPost = existingPost
    }

    var isEditing: Bool {
        existingPost != nil
    }

    func savePost(
        title: String,
        description: String,
        link: String,
        selectedTopics: Set<Topic>,
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let topics = Topic.allCases.filter { selectedTopics.contains($0) }

        if let existingPost {
            guard let userId = appState.authService.userId else { return }
            Task {
                await appState.communityService.updatePost(
                    existingPost,
                    title: trimmedTitle,
                    description: trimmedDescription,
                    link: trimmedLink.isEmpty ? nil : trimmedLink,
                    topics: topics,
                    editorId: userId)
                if let message = appState.communityService.errorMessage {
                    appState.presentError(message)
                }
            }
        }
        else {
            guard let user = appState.authService.user else { return }
            Task {
                await appState.communityService.createPost(
                    title: trimmedTitle,
                    description: trimmedDescription,
                    link: trimmedLink.isEmpty ? nil : trimmedLink,
                    topics: topics,
                    author: user,
                    authorDisplayName: appState.profileService.displayName)
                if let message = appState.communityService.errorMessage {
                    appState.presentError(message)
                }
            }
        }
    }
}
