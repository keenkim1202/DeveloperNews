import Foundation
import WidgetKit

/// Publishes the top stories to the shared container for the widget to read.
/// The two processes share no code: `WidgetStory` here and `TopStory` in the
/// widget are the ends of a serialized agreement — change one, change both.
@MainActor
enum WidgetSnapshotWriter {
    static let appGroupIdentifier = "group.keen-onit.DeveloperNews"
    static let storageKey = "widget.topStories"

    /// Enough to fill the largest widget family with a little slack, and small
    /// enough that the write stays cheap on every feed refresh.
    static let maxStories = 5

    private struct WidgetStory: Encodable {
        let title: String
        let sourceName: String
        let url: String
    }

    private struct StoredStory: Decodable {
        let url: String
    }

    /// Items the snapshot can carry. Both readers wrap what they find in a
    /// `devnews://article?url=` link whose parser takes http(s) only, so a
    /// followed user's post — a `devnews://community/...` URL — opens nothing.
    static func openableItems(_ items: [ContentItem]) -> [ContentItem] {
        items.filter { item in
            item.url.scheme == "https" || item.url.scheme == "http"
        }
    }

    /// The article at the top of the last published snapshot. Read from the
    /// container rather than `AppState`, so the answer is the same whether the
    /// app was already running or was just launched to serve the request.
    static func topStoryURL() -> URL? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: storageKey),
              let stories = try? JSONDecoder().decode([StoredStory].self, from: data)
        else { return nil }
        // Checked again on the way out: a snapshot written by an earlier
        // version of the app is still sitting in the container until the next
        // refresh, and it may hold a community URL.
        return stories
            .compactMap { URL(string: $0.url) }
            .first { $0.scheme == "https" || $0.scheme == "http" }
    }

    static func write(_ items: [ContentItem]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        let stories = openableItems(items).prefix(maxStories).map { item in
            WidgetStory(
                title: item.title,
                sourceName: item.sourceName,
                url: item.url.absoluteString)
        }

        guard let encoded = try? JSONEncoder().encode(stories) else {
            return
        }

        // Skip the reload when nothing changed. Widget refreshes are budgeted
        // by iOS, and spending one to redraw identical rows wastes budget the
        // next real update may need.
        let previous = defaults.data(forKey: storageKey)
        guard previous != encoded else {
            return
        }

        defaults.set(encoded, forKey: storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
