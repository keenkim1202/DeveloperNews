import SwiftUI
import WidgetKit

struct TopStoriesWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TopStoriesEntry

    /// Small shows one story and leans on its title; the taller families trade
    /// that emphasis for a list.
    private var visibleCount: Int {
        switch family {
        case .systemSmall:
            1
        case .systemMedium:
            3
        default:
            5
        }
    }

    private var stories: [TopStory] {
        Array(entry.stories.prefix(visibleCount))
    }

    var body: some View {
        if stories.isEmpty {
            emptyState
        }
        else {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
                header
                ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                    if index > 0 {
                        Divider()
                    }
                    row(for: story)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        Label("Top Stories", systemImage: "sparkles")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func row(for story: TopStory) -> some View {
        // Each row deep-links to its own article. On the small family the whole
        // widget is one tap target, which is why the link wraps the row rather
        // than the container.
        Link(destination: story.linkURL ?? URL(string: "https://example.com")!) {
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(family == .systemSmall ? .subheadline.weight(.semibold) : .caption)
                    .foregroundStyle(.primary)
                    .lineLimit(family == .systemSmall ? 4 : 2)
                    .multilineTextAlignment(.leading)
                Text(story.sourceName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text("Open DeveloperNews to load today's stories.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
