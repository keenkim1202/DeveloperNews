@preconcurrency import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class ActivityService: ActivityServicing {
    private(set) var activities: [Activity] = []
    private(set) var errorMessage: String?

    /// Size of the inbox window. Also keeps `markAllAsRead` under Firestore's
    /// 500-write batch limit without having to page.
    private static let listenerLimit = 100

    private let db = Firestore.firestore()
    private var userId: String?
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

        listenerRegistration = activitiesRef(userId)
            .order(by: "createdAt", descending: true)
            .limit(to: Self.listenerLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.activities = (snapshot?.documents ?? [])
                        .compactMap(ActivityDocument.parse)
                }
            }
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        userId = nil
        activities = []
    }

    func markAllAsRead() async {
        guard let userId else {
            return
        }
        let unreadIds = activities.filter { !$0.isRead }.map(\.id)
        guard !unreadIds.isEmpty else {
            return
        }

        let batch = db.batch()
        for id in unreadIds {
            batch.updateData(["isRead": true], forDocument: activitiesRef(userId).document(id))
        }

        do {
            try await batch.commit()
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Pages through the inbox rather than reading it whole, so a long-lived
    /// account does not have to fit its entire history in one query.
    func deleteInbox(userId: String) async throws {
        while true {
            let snapshot = try await activitiesRef(userId)
                .limit(to: Self.deletionPageSize)
                .getDocuments()
            guard !snapshot.documents.isEmpty else {
                return
            }

            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()

            if snapshot.documents.count < Self.deletionPageSize {
                return
            }
        }
    }

    /// Under Firestore's 500-write batch limit.
    private static let deletionPageSize = 200
}
