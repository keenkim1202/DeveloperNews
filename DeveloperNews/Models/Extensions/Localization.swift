import Foundation

protocol LocalizedTitle {
    var title: LocalizedStringResource { get }
}

extension Topic: LocalizedTitle {
    var title: LocalizedStringResource {
        switch self {
        case .web: .topicWeb
        case .ios: .topicIos
        case .android: .topicAndroid
        case .backend: .topicBackend
        case .ai: .topicAi
        case .security: .topicSecurity
        case .product: .topicProduct
        }
    }
}

extension SavedSortOrder: LocalizedTitle {
    var title: LocalizedStringResource {
        switch self {
        case .recentlySaved: .savedSortRecentlySaved
        case .trending: .savedSortTrending
        }
    }
}

extension SourceCategory: LocalizedTitle {
    var title: LocalizedStringResource {
        switch self {
        case .article: .sourceArticles
        case .hackerNews: .sourceHackerNews
        case .reddit: .sourceReddit
        case .github: .sourceGithub
        case .following: .sourceFollowing
        }
    }
}

extension ContentItem.Kind: LocalizedTitle {
    var title: LocalizedStringResource {
        switch self {
        case .article: .kindArticle
        case .discussion: .kindDiscussion
        }
    }
}
