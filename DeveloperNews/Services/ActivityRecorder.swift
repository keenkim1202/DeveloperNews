@preconcurrency import FirebaseFirestore
import Foundation

/// Writes activities into other users' inboxes.
///
/// Every write is best effort and deliberately silent: the caller has already
/// completed the like, comment, or follow the user asked for, and failing that
/// action because its notification could not be written would be worse than
/// dropping the notification. Self-directed activities are skipped so nobody is
/// told about their own actions.
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
