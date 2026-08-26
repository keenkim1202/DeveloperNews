@preconcurrency import FirebaseFirestore
import Foundation

/// Writes activities into other users' inboxes.
///
/// Best effort and deliberately silent: the like or comment the reader asked for
/// has already happened, and failing it over its notification would be worse
/// than dropping the notification. Self-directed activities are skipped.
@MainActor
final class ActivityRecorder: ActivityRecording {
    private let db = Firestore.firestore()

    private func activitiesRef(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("activities")
    }

    func set(_ draft: ActivityDraft) async {
        guard isDeliverable(draft) else {
            return
        }
        try? await activitiesRef(draft.recipientId)
            .document(ActivityDocument.stableId(for: draft))
            .setData(ActivityDocument.fields(for: draft))
    }

    func clear(_ draft: ActivityDraft) async {
        guard isDeliverable(draft) else {
            return
        }
        try? await activitiesRef(draft.recipientId)
            .document(ActivityDocument.stableId(for: draft))
            .delete()
    }

    private func isDeliverable(_ draft: ActivityDraft) -> Bool {
        !draft.recipientId.isEmpty && draft.recipientId != draft.actorId
    }
}
