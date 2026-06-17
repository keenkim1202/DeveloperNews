import SwiftUI

struct EngagementSummaryView: View {
    private let engagement: EngagementMetrics

    init(engagement: EngagementMetrics) {
        self.engagement = engagement
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Image(.upvote)
                Text(formatted(engagement.reactionCount))
            }
            HStack(spacing: 2) {
                Image(.commentAlt)
                Text(formatted(engagement.commentCount))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func formatted(_ value: Int) -> String {
        if value >= 1000 {
            let thousands = Double(value) / 1000
            return String(format: "%.1fk", thousands)
        }
        return "\(value)"
    }
}


// Read-only summary of this app's own in-app engagement on a story. Uses the
// .like/.comment icons so it reads as distinct from the source metrics above.
struct InAppEngagementSummaryView: View {
    private let engagement: StoryEngagement

    init(engagement: StoryEngagement) {
        self.engagement = engagement
    }

    private var hasCounts: Bool {
        engagement.likeCount + engagement.commentCount > 0
    }

    var body: some View {
        if hasCounts {
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    Image(.like)
                    Text(formatted(engagement.likeCount))
                }
                HStack(spacing: 2) {
                    Image(.comment)
                    Text(formatted(engagement.commentCount))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func formatted(_ value: Int) -> String {
        if value >= 1000 {
            let thousands = Double(value) / 1000
            return String(format: "%.1fk", thousands)
        }
        return "\(value)"
    }
}

