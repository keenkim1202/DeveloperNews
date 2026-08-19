import Foundation

/// A story as the app publishes it into the shared container.
///
/// The app's `WidgetSnapshotWriter.WidgetStory` is the other end of this
/// agreement. The widget shares no code with the app, so the two are kept in
/// step by their field names — the same arrangement the Share Extension uses.
struct TopStory: Decodable, Identifiable, Hashable {
    let title: String
    let sourceName: String
    let url: String

    var id: String {
        url
    }

    /// A `devnews://` link rather than the article URL itself, so a tap opens
    /// the app's reader — with its translation, engagement, and read tracking —
    /// instead of handing the story to Safari. `DeepLink` in the app parses it.
    var linkURL: URL? {
        var components = URLComponents()
        components.scheme = "devnews"
        components.host = "article"
        components.queryItems = [URLQueryItem(name: "url", value: url)]
        return components.url
    }
}

enum TopStoryStore {
    private static let appGroupIdentifier = "group.keen-onit.DeveloperNews"
    private static let storageKey = "widget.topStories"

    /// Empty when the app has not run since install, which the widget renders
    /// as a prompt to open it rather than as an error.
    static func load() -> [TopStory] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: storageKey),
              let stories = try? JSONDecoder().decode([TopStory].self, from: data)
        else { return [] }
        return stories
    }

    static let placeholder: [TopStory] = [
        TopStory(
            title: "Swift 6.3 tightens strict concurrency",
            sourceName: "Swift.org",
            url: "https://swift.org"),
        TopStory(
            title: "What shipped in SwiftUI this year",
            sourceName: "Hacker News",
            url: "https://news.ycombinator.com"),
        TopStory(
            title: "A closer look at Firestore security rules",
            sourceName: "Dev.to",
            url: "https://dev.to"),
    ]
}
