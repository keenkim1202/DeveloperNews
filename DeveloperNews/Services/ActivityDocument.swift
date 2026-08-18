@preconcurrency import FirebaseFirestore
import Foundation

/// Firestore representation of an `Activity`, shared by the write and read
/// sides so the field names and the document id are defined once.
enum ActivityDocument {
    /// Cap on the stored excerpt. Long enough to make a comment recognizable,
    /// short enough that an inbox of 100 rows stays a small read.
    static let maxPreviewLength = 140

    // `sending` so the caller can hand the dictionary straight to Firestore,
    // which consumes it off the main actor. The value is freshly built here and
    // never retained, so it is safe to transfer.
    static func fields(for draft: ActivityDraft) -> sending [String: Any] {
        var data: [String: Any] = [
            "kind": draft.kind.rawValue,
            "actorId": draft.actorId,
            "preview": String(draft.preview.prefix(maxPreviewLength)),
            "isRead": false,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let target = draft.target {
            data["targetCollection"] = target.collectionName
            data["targetPostId"] = target.postId
        }
        if let commentId = draft.commentId {
            data["commentId"] = commentId
        }
        if let parentCommentId = draft.parentCommentId {
            data["parentCommentId"] = parentCommentId
        }
        return data
    }

    /// Document id for a draft whose action is a toggle, so switching it on
    /// twice overwrites one row instead of stacking two. Every component is a
    /// Firebase-generated id or a fixed collection name, so the result is
    /// always a legal document id.
    static func stableId(for draft: ActivityDraft) -> String {
        var components = [draft.kind.rawValue]
        if let target = draft.target {
            components.append(target.collectionName)
            components.append(target.postId)
        }
        if let commentId = draft.commentId {
            components.append(commentId)
        }
        components.append(draft.actorId)
        return components.joined(separator: "_")
    }

    static func parse(_ doc: QueryDocumentSnapshot) -> Activity? {
        let data = doc.data()
        guard let kind = (data["kind"] as? String).flatMap(ActivityKind.init(rawValue:)),
              let actorId = data["actorId"] as? String
        else { return nil }

        let target = (data["targetCollection"] as? String).flatMap { collection in
            (data["targetPostId"] as? String).flatMap { postId in
                ActivityTarget(collectionName: collection, postId: postId)
            }
        }

        return Activity(
            id: doc.documentID,
            kind: kind,
            actorId: actorId,
            target: target,
            commentId: data["commentId"] as? String,
            parentCommentId: data["parentCommentId"] as? String,
            preview: data["preview"] as? String ?? "",
            // A just-written document reaches the local listener before the
            // server stamps `createdAt`, so fall back to now rather than to a
            // distant past that would sort the newest row to the bottom.
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            isRead: data["isRead"] as? Bool ?? false)
    }
}
