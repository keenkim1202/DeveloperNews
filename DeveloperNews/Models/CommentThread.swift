import Foundation

// A top-level comment with its single level of replies. The three comment
// screens render these so a reply appears nested under its parent.
struct CommentThread: Identifiable, Hashable, Sendable {
    let parent: CommunityComment
    let replies: [CommunityComment]

    var id: String {
        parent.id
    }

    // Groups a flat comment list into threads. Top-level comments (parentCommentId
    // == nil) keep their incoming order; replies are gathered under their parent
    // and sorted by createdAt ascending. Replies whose parent is absent from the
    // input (deleted or blocked-filtered) are dropped rather than shown as orphans.
    static func build(from comments: [CommunityComment]) -> [CommentThread] {
        let topLevel = comments.filter { $0.parentCommentId == nil }
        var repliesByParent: [String: [CommunityComment]] = [:]
        for comment in comments {
            guard let parentId = comment.parentCommentId else {
                continue
            }
            repliesByParent[parentId, default: []].append(comment)
        }
        return topLevel.map { parent in
            let replies = (repliesByParent[parent.id] ?? [])
                .sorted { $0.createdAt < $1.createdAt }
            return CommentThread(parent: parent, replies: replies)
        }
    }
}
