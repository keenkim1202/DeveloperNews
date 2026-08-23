import AppIntents
import Foundation

/// Opens whatever is at the top of the feed, from Siri, Spotlight or Shortcuts.
/// The story comes from the snapshot published for the widget, so the answer
/// does not wait on a fetch, and opening reuses the widget's `devnews://` link.
struct OpenTopStoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open the top story"

    static let description = IntentDescription(
        "Opens the story trending across your sources right now.")

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard let article = WidgetSnapshotWriter.topStoryURL(),
              let link = DeepLink.articleLink(to: article)
        else {
            throw TopStoryIntentError.noStoriesYet
        }
        return .result(opensIntent: OpenURLIntent(link))
    }
}

enum TopStoryIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noStoriesYet

    var localizedStringResource: LocalizedStringResource {
        "No stories yet. Open DeveloperNews once to load them."
    }
}
