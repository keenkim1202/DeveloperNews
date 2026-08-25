import FirebaseAuth
@preconcurrency import FirebaseFirestore
import Foundation

enum FeedPostServiceError: Error {
    /// The document exists but does not decode into a `FeedPost`.
    case malformedDocument(id: FeedPost.ID)
}

@Observable
@MainActor
final class FeedPostService: FeedPostServicing {
    private(set) var errorMessage: String?
    /// Bumped whenever the collection changes under a loaded feed — a post
    /// created, edited or deleted. `Community2ViewModel` skips a refetch while
    /// this is unchanged, so a screen that mutates a post has to move it or the
    /// feed behind it keeps showing what was there before.
    private(set) var changeToken = 0

    private let db = Firestore.firestore()
    private let activityRecorder: any ActivityRecording

    init(activityRecorder: any ActivityRecording = ActivityRecorder()) {
        self.activityRecorder = activityRecorder
    }

    // Firestore caps `in` queries at 10 values per request, so author batches
    // for the Following feed are chunked to stay within that limit.
    private static let inQueryChunkSize = 10

    private var feedPostsRef: CollectionReference {
        db.collection("feedPosts")
    }

    func createPost(
        comment: String,
        story: FeedPostStory,
        author: FirebaseAuth.User,
        authorDisplayName: String,
        authorEmoji: String?,
    ) async {
        errorMessage = nil

        let data: [String: Any] = [
            "authorId": author.uid,
            "authorName": authorDisplayName,
            "authorEmoji": authorEmoji ?? "",
            "comment": comment,
            "storyURL": story.url,
            "storyTitle": story.title,
            "storySourceName": story.sourceName,
            "storySourceCategory": story.sourceCategory.rawValue,
            "storyTopics": story.topics.map(\.rawValue),
            "storyThumbnailURL": story.thumbnailURL ?? "",
            "likeCount": 0,
            "likedBy": [String](),
            "commentCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        do {
            try await feedPostsRef.addDocument(data: data)
            changeToken += 1
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(
        _ post: FeedPost,
        userId: String,
    ) async {
        let ref = feedPostsRef.document(post.id)
        let isLiked = post.likedBy.contains(userId)

        do {
            if isLiked {
                try await ref.updateData([
                    "likedBy": FieldValue.arrayRemove([userId]),
                    "likeCount": FieldValue.increment(Int64(-1)),
                ])
            }
            else {
                try await ref.updateData([
                    "likedBy": FieldValue.arrayUnion([userId]),
                    "likeCount": FieldValue.increment(Int64(1)),
                ])
            }
        }
        catch {
            errorMessage = error.localizedDescription
            return
        }

        let draft = ActivityDraft(
            kind: .postLike,
            recipientId: post.authorId,
            actorId: userId,
            target: .feedPost(post.id),
            preview: post.comment)
        if isLiked {
            await activityRecorder.clear(draft)
        }
        else {
            await activityRecorder.set(draft)
        }
    }

    func updatePost(
        _ post: FeedPost,
        comment: String,
        editorId: String,
    ) async {
        errorMessage = nil

        guard post.authorId == editorId else {
            errorMessage = String(localized: .communityErrorNotAuthor)
            return
        }

        do {
            try await feedPostsRef.document(post.id).updateData([
                "comment": comment,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            changeToken += 1
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePost(_ post: FeedPost) async {
        errorMessage = nil
        do {
            try await feedPostsRef.document(post.id).delete()
            changeToken += 1
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func reportPost(
        _ post: FeedPost,
        reporterId: String,
        reason: String,
    ) async {
        let docId = "\(reporterId)_\(post.id)"
        do {
            try await db.collection("reports").document(docId).setData([
                "postId": post.id,
                "postTitle": post.story.title,
                "authorId": post.authorId,
                "reporterId": reporterId,
                "reason": reason,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reads the single feed post document for `id`.
    ///
    /// Returns nil only when the document is genuinely absent — the post was
    /// deleted, which is a normal outcome and not an error. A read that fails
    /// throws instead, because the two are indistinguishable to the caller
    /// otherwise, and a caller that maps both to "deleted" tells someone their
    /// post is gone every time the network drops.
    func post(id: FeedPost.ID) async throws -> FeedPost? {
        let snapshot = try await feedPostsRef.document(id).getDocument()
        guard snapshot.exists else {
            return nil
        }
        guard let post = Self.parsePost(snapshot) else {
            // The document is there but will not decode — a legacy shape, or a
            // required field gone. Returning nil here would report it as a
            // deletion, which is the one thing this signature exists to avoid.
            throw FeedPostServiceError.malformedDocument(id: id)
        }
        return post
    }

    func fetchRecentPosts(limit: Int) async -> [FeedPost] {
        do {
            let snapshot = try await feedPostsRef
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { Self.parsePost($0) }
        }
        catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func fetchPosts(byAuthor authorId: String) async -> [FeedPost] {
        do {
            let snapshot = try await feedPostsRef
                .whereField("authorId", isEqualTo: authorId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { Self.parsePost($0) }
        }
        catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func fetchPosts(byAuthors authorIds: [String]) async -> [FeedPost] {
        let uniqueIds = Array(Set(authorIds))
        guard !uniqueIds.isEmpty else {
            return []
        }

        var collected: [FeedPost] = []
        do {
            for chunk in uniqueIds.chunked(into: Self.inQueryChunkSize) {
                let snapshot = try await feedPostsRef
                    .whereField("authorId", in: chunk)
                    .getDocuments()
                collected.append(contentsOf: snapshot.documents.compactMap { Self.parsePost($0) })
            }
        }
        catch {
            errorMessage = error.localizedDescription
            return []
        }

        return collected.sorted { $0.createdAt > $1.createdAt }
    }

    // Takes a `DocumentSnapshot` so both collection queries and single-document
    // reads decode through here; a missing document has no data and yields nil.
    private static func parsePost(_ doc: DocumentSnapshot) -> FeedPost? {
        guard let data = doc.data() else {
            return nil
        }

        guard let authorId = data["authorId"] as? String,
              let comment = data["comment"] as? String,
              let storyURL = data["storyURL"] as? String,
              let storyTitle = data["storyTitle"] as? String
        else { return nil }

        let topicStrings = data["storyTopics"] as? [String] ?? []
        let topics = topicStrings.compactMap(Topic.init(rawValue:))
        let sourceCategory = (data["storySourceCategory"] as? String)
            .flatMap(SourceCategory.init(rawValue:)) ?? .article
        let likedByArray = data["likedBy"] as? [String] ?? []

        let story = FeedPostStory(
            url: storyURL,
            title: storyTitle,
            sourceName: data["storySourceName"] as? String ?? "",
            sourceCategory: sourceCategory,
            topics: topics,
            thumbnailURL: (data["storyThumbnailURL"] as? String).flatMap { $0.isEmpty ? nil : $0 })

        return FeedPost(
            id: doc.documentID,
            authorId: authorId,
            authorName: data["authorName"] as? String ?? "",
            authorEmoji: (data["authorEmoji"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            comment: comment,
            story: story,
            likeCount: max(0, data["likeCount"] as? Int ?? 0),
            likedBy: Set(likedByArray),
            commentCount: max(0, data["commentCount"] as? Int ?? 0),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue())
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
