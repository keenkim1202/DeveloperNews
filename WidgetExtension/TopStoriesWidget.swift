import SwiftUI
import WidgetKit

struct TopStoriesEntry: TimelineEntry {
    let date: Date
    let stories: [TopStory]
}

struct TopStoriesProvider: TimelineProvider {
    func placeholder(in context: Context) -> TopStoriesEntry {
        TopStoriesEntry(date: .now, stories: TopStoryStore.placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (TopStoriesEntry) -> Void,
    ) {
        // The gallery preview runs before the app has necessarily written
        // anything, so it falls back to sample rows rather than empty state.
        let stories = context.isPreview ? TopStoryStore.placeholder : TopStoryStore.load()
        completion(TopStoriesEntry(date: .now, stories: stories))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<TopStoriesEntry>) -> Void,
    ) {
        let entry = TopStoriesEntry(date: .now, stories: TopStoryStore.load())
        // The app reloads the timeline whenever the feed changes, so this is
        // only a floor for the case where the app has not been opened in a
        // while. iOS decides whether to honour it.
        let refreshAt = Date(timeIntervalSinceNow: 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(refreshAt)))
    }
}

struct TopStoriesWidget: Widget {
    private let kind = "TopStoriesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopStoriesProvider()) { entry in
            TopStoriesWidgetView(entry: entry)
        }
        .configurationDisplayName("Top Stories")
        .description("What is trending across your sources right now.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
