@preconcurrency import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class ActivityService: ActivityServicing {
    private(set) var activities: [Activity] = []
    private(set) var errorMessage: String?
    private(set) var canLoadMore = false

    /// How much of the inbox one window holds, and how much each `loadMore`
    /// adds to it.
    private static let windowStep = 100

    /// Under Firestore's 500-write batch limit. Writes that span the window are
    /// chunked to this, because the window keeps growing as the reader pages.
    private static let batchSize = 200

    private let db = Firestore.firestore()
    private var userId: String?
    private var windowLimit = ActivityService.windowStep

    /// Rows removed locally while their delete is in flight, so the row leaves
    /// on the swipe rather than the server round trip — and a mark-as-read batch
    /// running alongside skips a document whose absence would fail the batch.
    private var pendingDeletions: Set<Activity.ID> = []

    @ObservationIgnored
    nonisolated(unsafe) private var listenerRegistration: ListenerRegistration?

    deinit {
        listenerRegistration?.remove()
    }

    private func activitiesRef(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("activities")
    }

    func startListening(userId: String) {
        stopListening()
        self.userId = userId
        attachListener()
    }

    /// Other services clear `errorMessage` on entry to each call. This one
    /// cannot: the listener writes to the same field with no call in flight and
    /// the screen closed, so entry-clearing would swallow failures unseen.
    func clearError() {
        errorMessage = nil
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        userId = nil
        activities = []
        pendingDeletions = []
        windowLimit = Self.windowStep
        canLoadMore = false
    }

    /// Widens the window by a page. A listener carries its limit, so there is
    /// no asking it for more — the wider window is a new query, and the rows
    /// already on screen stay put until it lands.
    func loadMore() {
        guard canLoadMore else {
            return
        }
        windowLimit += Self.windowStep
        attachListener()
    }

    private func attachListener() {
        guard let userId else {
            return
        }
        listenerRegistration?.remove()

        listenerRegistration = activitiesRef(userId)
            .order(by: "createdAt", descending: true)
            .limit(to: windowLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    let documents = snapshot?.documents ?? []
                    // A full window is the only evidence there is more behind
                    // it; a short one means the query reached the end.
                    self.canLoadMore = documents.count >= self.windowLimit
                    self.activities = documents
                        .compactMap(ActivityDocument.parse)
                        .filter { !self.pendingDeletions.contains($0.id) }
                }
            }
    }

    func markAllAsRead() async {
        guard let userId else {
            return
        }
        let unreadIds = activities.filter { !$0.isRead }.map(\.id)
        guard !unreadIds.isEmpty else {
            return
        }

        do {
            for chunk in chunks(of: unreadIds) {
                let batch = db.batch()
                for id in chunk {
                    batch.updateData(["isRead": true], forDocument: activitiesRef(userId).document(id))
                }
                try await batch.commit()
            }
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(activityIds: [Activity.ID]) async {
        guard let userId, !activityIds.isEmpty else {
            return
        }
        let removed = Set(activityIds)
        pendingDeletions.formUnion(removed)
        activities.removeAll { removed.contains($0.id) }

        do {
            for chunk in chunks(of: activityIds) {
                let batch = db.batch()
                for id in chunk {
                    batch.deleteDocument(activitiesRef(userId).document(id))
                }
                try await batch.commit()
            }
            // Ids are derived from the action, so an unlike then a like writes
            // the same id again. Leaving it suppressed swallows that second row.
            pendingDeletions.subtract(removed)
        }
        catch {
            errorMessage = error.localizedDescription
            // The rows are still on the server. Re-attaching brings them back
            // rather than leaving the reader with a list that disagrees with
            // the server until the next launch.
            pendingDeletions.subtract(removed)
            attachListener()
        }
    }

    /// Pages through the inbox rather than reading it whole, so a long-lived
    /// account does not have to fit its entire history in one query.
    func deleteInbox(userId: String) async throws {
        while true {
            let snapshot = try await activitiesRef(userId)
                .limit(to: Self.batchSize)
                .getDocuments()
            guard !snapshot.documents.isEmpty else {
                return
            }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()

            if snapshot.documents.count < Self.batchSize {
                return
            }
        }
    }

    private func chunks(of ids: [Activity.ID]) -> [ArraySlice<Activity.ID>] {
        stride(from: 0, to: ids.count, by: Self.batchSize).map { start in
            ids[start..<min(start + Self.batchSize, ids.count)]
        }
    }
}
