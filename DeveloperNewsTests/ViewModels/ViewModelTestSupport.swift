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
        feedPost: MockFeedPostServicing = MockFeedPostServicing(),
        storyEngagement: MockStoryEngagementServicing = MockStoryEngagementServicing(),
        activity: MockActivityServicing = MockActivityServicing(),
        notifications: MockNotificationScheduling = MockNotificationScheduling(),
        summarizer: MockArticleSummarizing = MockArticleSummarizing(),
        translator: MockTranslating = MockTranslating(),
        contentSourceClient: (any ContentSourceClient)? = nil,
        pushRegistrar: PushRegistrar = PushRegistrar(store: MockPushTokenStoring()),
    ) -> AppState {
        AppState(
            translator: translator,
            authService: auth,
            profileService: profile,
            communityService: community,
            feedPostService: feedPost,
            storyEngagementService: storyEngagement,
            activityService: activity,
            notificationScheduler: notifications,
            articleSummarizer: summarizer,
            pushRegistrar: pushRegistrar,
            contentSourceClient: contentSourceClient,
            persistenceStore: makeIsolatedPersistenceStore())
    }

    // Each test gets a throwaway UserDefaults suite so persistence never reads or
    // writes the real app-group store, and no prior run can leak state in.
    static func makeIsolatedPersistenceStore() -> PersistenceStore {
        PersistenceStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
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

    static func makeFeedPost(
        id: String = UUID().uuidString,
        authorId: String = "author-1",
        authorName: String = "Author",
        authorEmoji: String? = nil,
        comment: String = "Worth a read",
        title: String = "Story Title",
        likeCount: Int = 0,
        likedBy: Set<String> = [],
        commentCount: Int = 0,
        createdAt: Date = .now,
    ) -> FeedPost {
        FeedPost(
            id: id,
            authorId: authorId,
            authorName: authorName,
            authorEmoji: authorEmoji,
            comment: comment,
            story: FeedPostStory(
                url: "https://example.com/\(id)",
                title: title,
                sourceName: "Source",
                sourceCategory: .article,
                topics: [.ios],
                thumbnailURL: nil),
            likeCount: likeCount,
            likedBy: likedBy,
            commentCount: commentCount,
            createdAt: createdAt,
            updatedAt: nil)
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
