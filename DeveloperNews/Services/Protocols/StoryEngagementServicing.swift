import Foundation

@MainActor
protocol StoryEngagementServicing {
    var errorMessage: String? { get }

    // Live document for the story currently being listened to, or nil when no
    // listener is active or the document does not exist yet.
    var engagement: StoryEngagement? { get }

    func startListening(storyURL: String)
    func stopListening()

    // Creates the engagement document with zeroed counts if it is missing. Must
    // be idempotent and must never clobber existing counts.
    func ensureDocument(storyURL: String) async

    func toggleLike(
        storyURL: String,
        userId: String,
    ) async

    // Counts a view at most once per device per calendar day. Local dedup state
    // is persisted so repeat opens within the same day do not re-increment.
    func registerView(storyURL: String) async

    func fetchEngagement(storyURL: String) async -> StoryEngagement?

    func fetchEngagements(storyURLs: [String]) async -> [String: StoryEngagement]
}
