import Foundation
import Observation

@Observable
@MainActor
final class FeedPostComposerViewModel {
    private let appState: AppState
    let item: ContentItem

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        self.appState = appState
        self.item = item
    }

    var story: FeedPostStory {
        Self.makeStory(from: item)
    }

    // Maps a feed ContentItem onto the persisted story shape. Kept static so the
    // mapping can be exercised without a signed-in FirebaseAuth user.
    static func makeStory(from item: ContentItem) -> FeedPostStory {
        FeedPostStory(
            url: item.url.absoluteString,
            title: item.title,
            sourceName: item.sourceName,
            sourceCategory: item.sourceCategory,
            topics: item.topics,
            thumbnailURL: item.thumbnailURL?.absoluteString)
    }

    @discardableResult
    func post(comment: String) async -> Bool {
        guard let user = appState.authService.user else {
            return false
        }

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        await appState.feedPostService.createPost(
            comment: trimmedComment,
            story: story,
            author: user,
            authorDisplayName: appState.profileService.displayName,
            authorEmoji: appState.profileService.profileEmoji)

        if let message = appState.feedPostService.errorMessage {
            appState.presentError(message)
            return false
        }

        return true
    }
}
