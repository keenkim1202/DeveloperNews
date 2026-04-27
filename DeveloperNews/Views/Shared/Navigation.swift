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

extension HomeTabDestination {
    /// Resolves a feed `ContentItem` to the matching Home-tab detail destination.
    /// Following feed -> community post detail, user-saved -> bookmark detail, otherwise -> external article.
    static func forFeedItem(
        _ item: ContentItem,
        communityService: CommunityService,
    ) -> HomeTabDestination {
        if item.sourceCategory == .following,
           let postId = item.url.pathComponents.last,
           communityService.post(id: postId) != nil {
            return .communityPostDetail(postId)
        }
        if item.isUserCreated {
            return .bookmarkDetail(item.url)
        }
        return .articleDetail(item.url)
    }
}

extension SavedTabDestination {
    /// Resolves a feed `ContentItem` to the matching Saved-tab detail destination.
    /// Following feed -> community post detail, user-saved -> bookmark detail, otherwise -> external article.
    static func forFeedItem(
        _ item: ContentItem,
        communityService: CommunityService,
    ) -> SavedTabDestination {
        if item.sourceCategory == .following,
           let postId = item.url.pathComponents.last,
           communityService.post(id: postId) != nil {
            return .communityPostDetail(postId)
        }
        if item.isUserCreated {
            return .bookmarkDetail(item.url)
        }
        return .articleDetail(item.url)
    }
}
