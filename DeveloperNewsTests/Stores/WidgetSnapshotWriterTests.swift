import Foundation
import Testing
@testable import DeveloperNews

// The widget and the App Intent both wrap what the snapshot holds in a
// `devnews://article?url=` link, and the parser on the other side takes http(s)
// only. What may go into the snapshot is therefore not "any feed item".
@MainActor
@Suite struct WidgetSnapshotWriterTests {
    private func makeItem(urlString: String) -> ContentItem {
        ContentItem(
            id: UUID(),
            kind: .article,
            title: "Title",
            summary: "Summary",
            sourceName: "Source",
            sourceCategory: .article,
            authorName: nil,
            url: URL(string: urlString)!,
            publishedAt: .now,
            topics: [.ios],
            trendScore: 0)
    }

    // A post from a followed user rides the same feed with a devnews:// URL. It
    // opened the app and then sat there, because the article parser rejects it.
    @Test func postsFromFollowedUsersAreLeftOut() {
        let items = [
            makeItem(urlString: "devnews://community/abc123"),
            makeItem(urlString: "https://example.com/a"),
        ]

        let openable = WidgetSnapshotWriter.openableItems(items)

        #expect(openable.map(\.url.absoluteString) == ["https://example.com/a"])
    }

    @Test func plainArticlesSurvive() {
        let items = [
            makeItem(urlString: "https://example.com/a"),
            makeItem(urlString: "http://example.com/b"),
        ]

        #expect(WidgetSnapshotWriter.openableItems(items).count == 2)
    }
}
