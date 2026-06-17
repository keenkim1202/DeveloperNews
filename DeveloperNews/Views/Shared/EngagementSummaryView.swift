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

