import FirebaseAuth
import FirebaseFirestore
import Foundation

struct CommunityComment: Identifiable, Hashable, Sendable {
    let id: String
    let postId: String
    let authorId: String
    let authorName: String
    let authorEmoji: String?
    let text: String
    let createdAt: Date
}

@Observable
@MainActor
final class CommentService {
    private(set) var comments: [CommunityComment] = []
    private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    private func commentsRef(_ postId: String) -> CollectionReference {
        db.collection("posts").document(postId).collection("comments")
    }

    func startListening(postId: String) {
        stopListening()

        listenerRegistration = commentsRef(postId)
            .order(by: "createdAt", descending: false)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
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
            try await db.collection("posts").document(postId).updateData([
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

            let postRef = db.collection("posts").document(comment.postId)
            let snapshot = try await postRef.getDocument()
            let current = snapshot.data()?["commentCount"] as? Int ?? 0
            try await postRef.updateData(["commentCount": max(0, current - 1)])
        }
        catch {
            errorMessage = error.localizedDescription
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
