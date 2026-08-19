import Foundation
import WidgetKit

/// Publishes the top stories to the shared container for the widget to read.
///
/// The widget is a separate process and shares no code with the app, matching
/// how the Share Extension already talks to it: both sides agree on a
/// serialized shape rather than a common type. `WidgetStory` here and
/// `TopStory` in the widget are the two ends of that agreement — change one and
/// the other must follow.
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

    static func write(_ items: [ContentItem]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        let stories = items.prefix(maxStories).map { item in
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
