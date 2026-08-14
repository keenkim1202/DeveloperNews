import SwiftUI

// One line of the activity inbox: who did what, an excerpt of the content it
// happened to, and when. Rendered by ActivityView only; it is a separate type
// so the row keeps its own layout out of the screen's list plumbing.
struct ActivityRow: View {
    private let activity: Activity
    private let actor: UserSummary?
    private let isUnread: Bool

    init(
        activity: Activity,
        actor: UserSummary?,
        isUnread: Bool,
    ) {
        self.activity = activity
        self.actor = actor
        self.isUnread = isUnread
    }

    // Falls back to a placeholder while the actor lookup is in flight, and for
    // an actor whose profile is gone.
    private var actorName: String {
        let name = actor?.displayName ?? ""
        return name.isEmpty ? String(localized: .activitySomeone) : name
    }

    private var message: Text {
        switch activity.kind {
        case .postLike:
            Text("\(actorName) liked your post")
        case .postComment:
            Text("\(actorName) commented on your post")
        case .commentReply:
            Text("\(actorName) replied to your comment")
        case .commentLike:
            Text("\(actorName) liked your comment")
        case .follow:
            Text("\(actorName) started following you")
        }
    }

    private var icon: DSIcon {
        switch activity.kind {
        case .postLike, .commentLike:
            .likeFilled
        case .postComment:
            .comment
        case .commentReply:
            .commentAlt
        case .follow:
            .account
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                message
                    .font(.dsCardTitle)
                    .multilineTextAlignment(.leading)
                if !activity.preview.isEmpty {
                    Text(activity.preview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(relativeDateFormatter.localizedString(for: activity.createdAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if isUnread {
                Circle()
                    .fill(DSColor.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            isUnread ? DSColor.accent.opacity(0.06) : Color.clear
        }
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let emoji = actor?.emoji {
                    Text(emoji)
                        .font(.title3)
                }
                else {
                    Image(.unknown)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .background(DSColor.surface)
            .clipShape(Circle())

            Image(icon)
                .font(.caption2)
                .foregroundStyle(DSColor.accent)
                .padding(3)
                .background(DSColor.background)
                .clipShape(Circle())
        }
    }
}
