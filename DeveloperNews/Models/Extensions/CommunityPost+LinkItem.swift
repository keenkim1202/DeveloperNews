import Foundation

extension CommunityPost {
    /// The post's external link represented as a feed `ContentItem`, used to open
    /// the link in the article detail screen. Nil when the post has no valid link.
    var linkContentItem: ContentItem? {
        guard hasLink,
              let url = linkURL
        else {
            return nil
        }
        return ContentItem(
            id: UUID(),
            kind: .article,
            title: title,
            summary: "",
            sourceName: authorName,
            sourceCategory: .article,
            authorName: authorName,
            url: url,
            publishedAt: createdAt,
            topics: topics,
            trendScore: 0)
    }
}
