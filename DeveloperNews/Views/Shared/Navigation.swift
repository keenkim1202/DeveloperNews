import Foundation
import Observation

enum HomeTabDestination: Hashable {
    case articleDetail(URL)
    case bookmarkDetail(URL)
    case communityPostDetail(CommunityPost.ID)
    case userProfile(AuthorInfo)
}

enum CommunityTabDestination: Hashable {
    case postDetail(CommunityPost.ID)
    case userProfile(AuthorInfo)
    case postLinkDetail(CommunityPost.ID)
}

enum SavedTabDestination: Hashable {
    case articleDetail(URL)
    case bookmarkDetail(URL)
    case communityPostDetail(CommunityPost.ID)
    case userProfile(AuthorInfo)
}

enum SettingsTabDestination: Hashable {
    case blockedUsers
    case sourcesAttribution
    case privacyPolicy
    case termsOfUse
    case userProfile(AuthorInfo)
}

enum AppDestination: Hashable {
    case home(HomeTabDestination)
    case community(CommunityTabDestination)
    case saved(SavedTabDestination)
    case settings(SettingsTabDestination)
}

@Observable
@MainActor
final class Navigation {
    var home: [HomeTabDestination] = []
    var community: [CommunityTabDestination] = []
    var saved: [SavedTabDestination] = []
    var settings: [SettingsTabDestination] = []

    func callAsFunction(_ destination: AppDestination) {
        switch destination {
        case let .home(dest):
            home.append(dest)
        case let .community(dest):
            community.append(dest)
        case let .saved(dest):
            saved.append(dest)
        case let .settings(dest):
            settings.append(dest)
        }
    }
}

/// Tab-agnostic resolution of a feed `ContentItem` to its detail route.
/// Following feed -> community post, user-saved -> bookmark, otherwise -> external article.
private enum FeedItemRoute {
    case communityPost(CommunityPost.ID)
    case bookmark(URL)
    case article(URL)

    static func forFeedItem(
        _ item: ContentItem,
        communityService: CommunityService,
    ) -> FeedItemRoute {
        if item.sourceCategory == .following,
           let postId = item.url.pathComponents.last,
           communityService.post(id: postId) != nil {
            return .communityPost(postId)
        }
        if item.isUserCreated {
            return .bookmark(item.url)
        }
        return .article(item.url)
    }
}

extension HomeTabDestination {
    /// Resolves a feed `ContentItem` to the matching Home-tab detail destination.
    static func forFeedItem(
        _ item: ContentItem,
        communityService: CommunityService,
    ) -> HomeTabDestination {
        switch FeedItemRoute.forFeedItem(item, communityService: communityService) {
        case let .communityPost(postId):
            return .communityPostDetail(postId)
        case let .bookmark(url):
            return .bookmarkDetail(url)
        case let .article(url):
            return .articleDetail(url)
        }
    }
}

extension SavedTabDestination {
    /// Resolves a feed `ContentItem` to the matching Saved-tab detail destination.
    static func forFeedItem(
        _ item: ContentItem,
        communityService: CommunityService,
    ) -> SavedTabDestination {
        switch FeedItemRoute.forFeedItem(item, communityService: communityService) {
        case let .communityPost(postId):
            return .communityPostDetail(postId)
        case let .bookmark(url):
            return .bookmarkDetail(url)
        case let .article(url):
            return .articleDetail(url)
        }
    }
}
