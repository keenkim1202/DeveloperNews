import Foundation

/// Everything needed to write one activity into a recipient's inbox.
struct ActivityDraft: Hashable, Sendable {
    let kind: ActivityKind
    let recipientId: String
    let actorId: String
    let target: ActivityTarget?
    let commentId: String?
    let preview: String

    init(
        kind: ActivityKind,
        recipientId: String,
        actorId: String,
        target: ActivityTarget? = nil,
        commentId: String? = nil,
        preview: String = "",
    ) {
        self.kind = kind
        self.recipientId = recipientId
        self.actorId = actorId
        self.target = target
        self.commentId = commentId
        self.preview = preview
    }
}

/// Write side of the activity inbox.
///
/// Split from `ActivityServicing` because the two have disjoint callers: the
/// services that mutate content only ever write, and only the inbox screen ever
/// reads. Every method is best effort — a failed write must not surface as a
/// failure of the like, comment, or follow that triggered it.
@MainActor
protocol ActivityRecording {
    /// Adds an activity for an action that can genuinely happen more than once,
    /// such as posting a second comment on the same post.
    func append(_ draft: ActivityDraft) async

    /// Writes an activity under an id derived from the draft, so a toggle that
    /// is switched on twice leaves one row rather than two.
    func set(_ draft: ActivityDraft) async

    /// Removes the activity `set(_:)` writes for the same draft.
    func clear(_ draft: ActivityDraft) async
}
