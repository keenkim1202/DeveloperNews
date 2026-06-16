import Foundation
@testable import DeveloperNews

// Shared factories for view-model tests: build AppState from mocks and produce
// ContentItem / CommunityPost fixtures with sensible defaults.
@MainActor
enum VMFixtures {
    static func makeAppState(
        auth: MockAuthServicing = MockAuthServicing(),
        profile: MockProfileServicing = MockProfileServicing(),
        community: MockCommunityServicing = MockCommunityServicing(),
        translator: MockTranslating = MockTranslating(),
        contentSourceClient: (any ContentSourceClient)? = nil,
    ) -> AppState {
        AppState(
            translator: translator,
            authService: auth,
            profileService: profile,
            communityService: community,
            contentSourceClient: contentSourceClient)
    }

    // The persistence store is backed by a shared app-group UserDefaults suite,
    // so a freshly built AppState may carry over saved items / selected topics
    // from a prior run on the same simulator. Normalize to a blank slate so each
    // test asserts against deterministic state.
    static func resetState(_ appState: AppState) {
        for url in Array(appState.savedItemSnapshots.keys) {
            appState.removeSavedItem(at: url)
        }
        for topic in Array(appState.selectedTopics) {
            appState.toggleTopic(topic)
        }
        appState.blockedUserIds = []
    }

    // Lets AppState-owned persistence tasks settle before the instance is
    // released, so teardown does not race a pending Task (which crashes).
    // Yields repeatedly because a chained write awaits the prior one.
    static func drainPersistence() async {
        for _ in 0..<20 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(20))
    }

    static func makeItem(
        kind: ContentItem.Kind = .article,
        title: String = "Title",
        summary: String = "Summary",
        sourceName: String = "Source",
        urlString: String = "https://example.com/\(UUID().uuidString)",
        topics: [Topic] = [.ios],
        trendScore: Int = 0,
    ) -> ContentItem {
        ContentItem(
            id: UUID(),
            kind: kind,
            title: title,
            summary: summary,
            sourceName: sourceName,
            sourceCategory: kind == .article ? .article : .hackerNews,
            authorName: nil,
            url: URL(string: urlString)!,
            publishedAt: .now,
            topics: topics,
            trendScore: trendScore)
    }

    static func makePost(
        id: String = UUID().uuidString,
        authorId: String = "author-1",
        authorName: String = "Author",
        title: String = "Post Title",
        description: String = "Post Description",
        topics: [Topic] = [.ios],
    ) -> CommunityPost {
        CommunityPost(
            id: id,
            authorId: authorId,
            authorName: authorName,
            title: title,
            description: description,
            link: nil,
            topics: topics,
            likeCount: 0,
            likedBy: [],
            commentCount: 0,
            createdAt: .now,
            updatedAt: nil)
    }
}

// Stub content source returning canned items, so feed-derived state
// (personalizedItems, paged items) can be seeded via AppState.reload().
struct StubContentSourceClient: ContentSourceClient {
    let items: [ContentItem]

    func fetchItems(selectedTopics: Set<Topic>) async throws -> [ContentItem] {
        items
    }
}
