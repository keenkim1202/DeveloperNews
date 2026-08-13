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
    private let activityRecorder: any ActivityRecording
    @ObservationIgnored
    nonisolated(unsafe) private var listenerRegistration: ListenerRegistration?

    init(
        parentCollection: String = "posts",
        activityRecorder: any ActivityRecording = ActivityRecorder(),
    ) {
        self.parentCollection = parentCollection
        self.activityRecorder = activityRecorder
    }

    /// The activity destination for a post in this service's parent
    /// collection. Nil for `storyEngagement`, whose ids are URL hashes with no
    /// detail route, which suppresses activity for story comments.
    private func activityTarget(postId: String) -> ActivityTarget? {
        ActivityTarget(collectionName: parentCollection, postId: postId)
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
        postAuthorId: String,
        text: String,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
        parentCommentId: String? = nil,
    ) async {
        errorMessage = nil

        // Resolved before the write so the reply target comes from the same
        // snapshot the user was replying to.
        let parentComment = parentCommentId.flatMap { id in
            comments.first { $0.id == id }
        }

        var data: [String: Any] = [
            "authorId": author.uid,
            "authorName": authorDisplayName,
            "authorEmoji": authorEmoji ?? "",
            "text": text,
            "likeCount": 0,
            "likedBy": [String](),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let parentCommentId {
            data["parentCommentId"] = parentCommentId
        }

        let newCommentId: String
        do {
            newCommentId = try await commentsRef(postId).addDocument(data: data).documentID
            try await db.collection(parentCollection).document(postId).updateData([
                "commentCount": FieldValue.increment(Int64(1)),
            ])
        }
        catch {
            errorMessage = error.localizedDescription
            return
        }

        guard let target = activityTarget(postId: postId) else {
            return
        }
        // A reply notifies whoever it answers; a top-level comment notifies the
        // post author. A reply whose parent is outside the listener window is
        // recorded as a plain comment to the post author rather than as a reply
        // to someone we cannot name.
        await activityRecorder.append(ActivityDraft(
            kind: parentComment == nil ? .postComment : .commentReply,
            recipientId: parentComment?.authorId ?? postAuthorId,
            actorId: author.uid,
            target: target,
            commentId: newCommentId,
            preview: text))
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

    func toggleCommentLike(
        _ comment: CommunityComment,
        userId: String,
    ) async {
        errorMessage = nil
        let wasLiked = comment.likedBy.contains(userId)
        do {
            try await Self.runCommentLikeTransaction(
                db,
                parentCollection: parentCollection,
                postId: comment.postId,
                commentId: comment.id,
                userId: userId)
        }
        catch {
            errorMessage = error.localizedDescription
            return
        }

        guard let target = activityTarget(postId: comment.postId) else {
            return
        }
        let draft = ActivityDraft(
            kind: .commentLike,
            recipientId: comment.authorId,
            actorId: userId,
            target: target,
            commentId: comment.id,
            preview: comment.text)
        if wasLiked {
            await activityRecorder.clear(draft)
        }
        else {
            await activityRecorder.set(draft)
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

    // nonisolated so the transaction closure captures only the local Firestore
    // handle and comment ids rather than MainActor-isolated `self`. Mirrors the
    // post-level membership-tied +-1 toggle on likedBy/likeCount.
    nonisolated private static func runCommentLikeTransaction(
        _ db: Firestore,
        parentCollection: String,
        postId: String,
        commentId: String,
        userId: String,
    ) async throws {
        let commentRef = db.collection(parentCollection)
            .document(postId)
            .collection("comments")
            .document(commentId)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(commentRef)
            }
            catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            let data = snapshot.data()
            let likedBy = data?["likedBy"] as? [String] ?? []
            let current = data?["likeCount"] as? Int ?? 0
            if likedBy.contains(userId) {
                transaction.updateData(
                    [
                        "likedBy": FieldValue.arrayRemove([userId]),
                        "likeCount": max(0, current - 1),
                    ],
                    forDocument: commentRef)
            }
            else {
                transaction.updateData(
                    [
                        "likedBy": FieldValue.arrayUnion([userId]),
                        "likeCount": max(0, current) + 1,
                    ],
                    forDocument: commentRef)
            }
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
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            likeCount: max(0, data["likeCount"] as? Int ?? 0),
            likedBy: Set(data["likedBy"] as? [String] ?? []),
            parentCommentId: data["parentCommentId"] as? String)
    }
}
