import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct Community2ViewModelTests {
    @Test func moreEngagementScoresHigherAtSameAge() {
        let low = Community2ViewModel.trendingScore(
            likeCount: 1,
            commentCount: 0,
            ageHours: 5)
        let high = Community2ViewModel.trendingScore(
            likeCount: 10,
            commentCount: 0,
            ageHours: 5)

        #expect(high > low)
    }

    @Test func commentsWeighDoubleLikes() {
        let likes = Community2ViewModel.trendingScore(
            likeCount: 2,
            commentCount: 0,
            ageHours: 5)
        let comments = Community2ViewModel.trendingScore(
            likeCount: 0,
            commentCount: 2,
            ageHours: 5)

        #expect(comments > likes)
    }

    @Test func olderPostScoresLowerWithEqualEngagement() {
        let fresh = Community2ViewModel.trendingScore(
            likeCount: 5,
            commentCount: 1,
            ageHours: 1)
        let old = Community2ViewModel.trendingScore(
            likeCount: 5,
            commentCount: 1,
            ageHours: 100)

        #expect(fresh > old)
    }

    @Test func freshLowEngagementCanOutrankOldHighEngagement() {
        let freshLow = Community2ViewModel.trendingScore(
            likeCount: 2,
            commentCount: 0,
            ageHours: 1)
        let oldHigh = Community2ViewModel.trendingScore(
            likeCount: 50,
            commentCount: 0,
            ageHours: 720)

        #expect(freshLow > oldHigh)
    }

    @Test func recentPostsSortedByCreatedAtDescending() async {
        let feedPost = MockFeedPostServicing()
        let older = VMFixtures.makeFeedPost(
            id: "older",
            createdAt: Date(timeIntervalSinceNow: -10_000))
        let newer = VMFixtures.makeFeedPost(
            id: "newer",
            createdAt: Date(timeIntervalSinceNow: -100))
        feedPost.recentPosts = [older, newer]
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)

        await vm.load()

        #expect(vm.recentPosts.map(\.id) == ["newer", "older"])
        #expect(feedPost.fetchedRecentLimits == [200])
    }

    @Test func trendingPutsFreshHighEngagementFirst() async {
        let feedPost = MockFeedPostServicing()
        // Old but heavily engaged.
        let oldHot = VMFixtures.makeFeedPost(
            id: "oldHot",
            likeCount: 40,
            commentCount: 5,
            createdAt: Date(timeIntervalSinceNow: -3600 * 240))
        // Fresh with modest engagement.
        let freshWarm = VMFixtures.makeFeedPost(
            id: "freshWarm",
            likeCount: 6,
            commentCount: 2,
            createdAt: Date(timeIntervalSinceNow: -3600))
        feedPost.recentPosts = [oldHot, freshWarm]
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)

        await vm.load()

        #expect(vm.trendingPosts.first?.id == "freshWarm")
        // Recent ordering is independent of the trending ranking.
        #expect(vm.recentPosts.first?.id == "freshWarm")
    }

    @Test func toggleLikeWhileSignedOutIsNoOp() async {
        let feedPost = MockFeedPostServicing()
        let post = VMFixtures.makeFeedPost(id: "p1")
        feedPost.recentPosts = [post]
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(),
            feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)
        await vm.load()

        await vm.toggleLike(post)

        #expect(feedPost.toggledLikes.isEmpty)
    }

    @Test func followingPostsLoadSortedByCreatedAtDescending() async {
        let feedPost = MockFeedPostServicing()
        let older = VMFixtures.makeFeedPost(
            id: "older",
            createdAt: Date(timeIntervalSinceNow: -10_000))
        let newer = VMFixtures.makeFeedPost(
            id: "newer",
            createdAt: Date(timeIntervalSinceNow: -100))
        feedPost.authorsPosts = [older, newer]
        let profile = MockProfileServicing()
        profile.followedUserIds = ["author-1", "author-2"]
        let appState = VMFixtures.makeAppState(
            profile: profile,
            feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)

        await vm.loadFollowing()

        #expect(vm.followingPosts.map(\.id) == ["newer", "older"])
        #expect(feedPost.fetchedAuthorBatches.count == 1)
        #expect(Set(feedPost.fetchedAuthorBatches[0]) == ["author-1", "author-2"])
    }

    @Test func emptyFollowSetYieldsEmptyFollowingFeed() async {
        let feedPost = MockFeedPostServicing()
        feedPost.authorsPosts = [VMFixtures.makeFeedPost(id: "p1")]
        let profile = MockProfileServicing()
        profile.followedUserIds = []
        let appState = VMFixtures.makeAppState(
            profile: profile,
            feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)

        await vm.loadFollowing()

        #expect(vm.followingPosts.isEmpty)
        #expect(vm.hasLoadedFollowing)
        #expect(feedPost.fetchedAuthorBatches.isEmpty)
    }

    @Test func toggleLikeUpdatesFollowingPost() async {
        let feedPost = MockFeedPostServicing()
        let post = VMFixtures.makeFeedPost(id: "p1", likeCount: 2)
        feedPost.authorsPosts = [post]
        let profile = MockProfileServicing()
        profile.followedUserIds = ["author-1"]
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            profile: profile,
            feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)
        await vm.loadFollowing()

        await vm.toggleLike(post)

        let updated = vm.followingPosts.first { $0.id == "p1" }
        #expect(updated?.likeCount == 3)
        #expect(updated?.likedBy.contains("me") == true)
    }

    @Test func blockedAuthorsAreFilteredFromDiscoverFeed() async {
        let feedPost = MockFeedPostServicing()
        let visible = VMFixtures.makeFeedPost(id: "visible", authorId: "ok")
        let hidden = VMFixtures.makeFeedPost(id: "hidden", authorId: "blocked")
        feedPost.recentPosts = [visible, hidden]
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        appState.blockUser("blocked")
        let vm = Community2ViewModel(appState: appState)

        await vm.load()

        #expect(vm.recentPosts.map(\.id) == ["visible"])
        #expect(vm.trendingPosts.map(\.id) == ["visible"])
        #expect(vm.displayedPosts.map(\.id) == ["visible"])

        await Task.yield()
    }

    @Test func blockedAuthorsAreFilteredFromFollowingFeed() async {
        let feedPost = MockFeedPostServicing()
        let visible = VMFixtures.makeFeedPost(id: "visible", authorId: "ok")
        let hidden = VMFixtures.makeFeedPost(id: "hidden", authorId: "blocked")
        feedPost.authorsPosts = [visible, hidden]
        let profile = MockProfileServicing()
        profile.followedUserIds = ["ok", "blocked"]
        let appState = VMFixtures.makeAppState(
            profile: profile,
            feedPost: feedPost)
        appState.blockUser("blocked")
        let vm = Community2ViewModel(appState: appState)

        await vm.loadFollowing()

        #expect(vm.visibleFollowingPosts.map(\.id) == ["visible"])
        #expect(vm.hasNoFollowingPosts == false)

        await Task.yield()
    }

    @Test func toggleLikeUpdatesLocalStateWhenSignedIn() async {
        let feedPost = MockFeedPostServicing()
        let post = VMFixtures.makeFeedPost(id: "p1", likeCount: 3)
        feedPost.recentPosts = [post]
        let appState = VMFixtures.makeAppState(
            auth: MockAuthServicing(userId: "me"),
            feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)
        await vm.load()

        await vm.toggleLike(post)

        #expect(feedPost.toggledLikes.map(\.postId) == ["p1"])
        let updated = vm.posts.first { $0.id == "p1" }
        #expect(updated?.likeCount == 4)
        #expect(updated?.likedBy.contains("me") == true)
    }

    @Test func loadIfNeededSkipsRefetchWhenNoPostCreated() async {
        let feedPost = MockFeedPostServicing()
        feedPost.recentPosts = [VMFixtures.makeFeedPost(id: "p1")]
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()

        #expect(feedPost.fetchedRecentLimits == [200])
    }

    @Test func loadIfNeededRefetchesAfterPostCreated() async {
        let feedPost = MockFeedPostServicing()
        feedPost.recentPosts = [VMFixtures.makeFeedPost(id: "p1")]
        let appState = VMFixtures.makeAppState(feedPost: feedPost)
        let vm = Community2ViewModel(appState: appState)
        await vm.loadIfNeeded()

        // Simulate a post created from another screen, bumping the token.
        feedPost.creationToken += 1
        await vm.loadIfNeeded()

        #expect(feedPost.fetchedRecentLimits == [200, 200])
    }
}
