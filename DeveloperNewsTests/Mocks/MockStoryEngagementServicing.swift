import Foundation
@testable import DeveloperNews

@MainActor
final class MockStoryEngagementServicing: StoryEngagementServicing {
    var errorMessage: String?
    var engagement: StoryEngagement?

    // Seeded return values for the one-shot reads.
    var fetchedEngagement: StoryEngagement?
    var fetchedEngagements: [String: StoryEngagement] = [:]

    private(set) var listeningStoryURL: String?
    private(set) var didStopListening = false
    private(set) var ensuredURLs: [String] = []
    private(set) var toggledLikes: [(storyURL: String, userId: String)] = []
    private(set) var fetchedURLs: [String] = []
    private(set) var fetchedBatches: [[String]] = []

    func startListening(storyURL: String) {
        listeningStoryURL = storyURL
    }

    func stopListening() {
        didStopListening = true
    }

    func ensureDocument(storyURL: String) async {
        ensuredURLs.append(storyURL)
    }

    func toggleLike(
        storyURL: String,
        userId: String,
    ) async {
        toggledLikes.append((storyURL, userId))
    }

    func fetchEngagement(storyURL: String) async -> StoryEngagement? {
        fetchedURLs.append(storyURL)
        return fetchedEngagement
    }

    func fetchEngagements(storyURLs: [String]) async -> [String: StoryEngagement] {
        fetchedBatches.append(storyURLs)
        return fetchedEngagements
    }
}
