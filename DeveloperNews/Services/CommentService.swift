import FirebaseAuth
@preconcurrency import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class CommentService: CommentServicing {
    private(set) var comments: [CommunityComment] = []
    private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private let parentCollection: String
    @ObservationIgnored
    nonisolated(unsafe) private var listenerRegistration: ListenerRegistration?

    init(parentCollection: String = "posts") {
        self.parentCollection = parentCollection
    }

    deinit {
        listenerRegistration?.remove()
    }

    private func commentsRef(_ postId: String) -> CollectionReference {
        db.collection(parentCollection).document(postId).collection("comments")
    }

    func startListening(postId: String) {
        stopListening()

        listenerRegistration = commentsRef(postId)
            .order(by: "createdAt", descending: false)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    let documents = snapshot?.documents ?? []
                    self.comments = documents
                        .compactMap { Self.parseComment($0, postId: postId) }
                        .sorted { $0.createdAt < $1.createdAt }
                }
            }
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        comments = []
    }

    func addComment(
        postId: String,
        text: String,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
    ) async {
        errorMessage = nil

        let data: [String: Any] = [
            "authorId": author.uid,
            "authorName": authorDisplayName,
            "authorEmoji": authorEmoji ?? "",
            "text": text,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        do {
            try await commentsRef(postId).addDocument(data: data)
            try await db.collection(parentCollection).document(postId).updateData([
                "commentCount": FieldValue.increment(Int64(1)),
            ])
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(_ comment: CommunityComment) async {
        errorMessage = nil
        do {
            try await commentsRef(comment.postId).document(comment.id).delete()

            // Atomic, clamped decrement. Security rules reject commentCount < 0,
            // so we can't use FieldValue.increment(-1) on a 0-count post; a
            // transaction lets us read-modify-write safely under contention.
            try await Self.decrementCommentCount(
                db,
                parentCollection: parentCollection,
                postId: comment.postId)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func reportComment(
        _ comment: CommunityComment,
        reporterId: String,
        reason: String,
    ) async {
        errorMessage = nil
        let docId = "\(reporterId)_\(comment.id)"
        do {
            try await db.collection("reports").document(docId).setData([
                "reporterId": reporterId,
                "commentId": comment.id,
                "reportedUserId": comment.authorId,
                "parentCollection": parentCollection,
                "postId": comment.postId,
                "reason": reason,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    // nonisolated so the transaction closure captures only the local Firestore
    // handle and post id rather than MainActor-isolated `self`.
    nonisolated private static func decrementCommentCount(
        _ db: Firestore,
        parentCollection: String,
        postId: String,
    ) async throws {
        let postRef = db.collection(parentCollection).document(postId)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(postRef)
            }
            catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            let current = snapshot.data()?["commentCount"] as? Int ?? 0
            transaction.updateData(["commentCount": max(0, current - 1)], forDocument: postRef)
            return nil
        }
    }

    private static func parseComment(
        _ doc: QueryDocumentSnapshot,
        postId: String,
    ) -> CommunityComment? {
        let data = doc.data()
        guard let authorId = data["authorId"] as? String,
              let text = data["text"] as? String
        else { return nil }

        return CommunityComment(
            id: doc.documentID,
            postId: postId,
            authorId: authorId,
            authorName: data["authorName"] as? String ?? "",
            authorEmoji: (data["authorEmoji"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            text: text,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
    }
}
