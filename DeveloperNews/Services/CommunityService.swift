import FirebaseAuth
import FirebaseFirestore
import Foundation

enum CommunityServiceError: Error {
    /// The document exists but does not decode into a `CommunityPost`.
    case malformedDocument(id: CommunityPost.ID)
}

@Observable
@MainActor
final class CommunityService: CommunityServicing {
    private(set) var posts: [CommunityPost] = [] {
        didSet {
            postsByID = Dictionary(
                posts.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first })
        }
    }

    // Lookup index for post(id:), which detail rows call once per row.
    private var postsByID: [CommunityPost.ID: CommunityPost] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var authorEmojiCache: [String: String] = [:]

    private let db = Firestore.firestore()
    private let activityRecorder: any ActivityRecording
    private var listenerRegistration: ListenerRegistration?
    private var authorEmojiFetchGeneration = 0

    init(activityRecorder: any ActivityRecording = ActivityRecorder()) {
        self.activityRecorder = activityRecorder
    }

    private var postsRef: CollectionReference {
        db.collection("posts")
    }

    /// Looks up a `CommunityPost` by id in the currently loaded posts.
    /// Returns nil if the post has been deleted or is not yet loaded.
    func post(id: CommunityPost.ID) -> CommunityPost? {
        postsByID[id]
    }

    func fetchPost(id: CommunityPost.ID) async throws -> CommunityPost? {
        let snapshot = try await postsRef.document(id).getDocument()
        guard snapshot.exists else {
            return nil
        }
        guard let post = Self.parsePost(snapshot) else {
            throw CommunityServiceError.malformedDocument(id: id)
        }
        return post
    }

    func startListening() {
        stopListening()
        isLoading = true

        listenerRegistration = postsRef
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.posts = []
                        return
                    }

                    self.posts = documents.compactMap { doc in
                        Self.parsePost(doc)
                    }
                    self.authorEmojiFetchGeneration += 1
                    await self.fetchAuthorEmojis(generation: self.authorEmojiFetchGeneration)
                }
            }
    }

    func refresh() async {
        do {
            let snapshot = try await postsRef
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            posts = snapshot.documents.compactMap { Self.parsePost($0) }
            authorEmojiFetchGeneration += 1
            await fetchAuthorEmojis(generation: authorEmojiFetchGeneration)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
    }

    func createPost(
        title: String,
        description: String,
        link: String?,
        topics: [Topic],
        author: FirebaseAuth.User,
        authorDisplayName: String,
    ) async {
        errorMessage = nil

        let data: [String: Any] = [
            "authorId": author.uid,
            "authorName": authorDisplayName,
            "title": title,
            "description": description,
            "link": link ?? "",
            "topics": topics.map(\.rawValue),
            "likeCount": 0,
            "likedBy": [String](),
            "commentCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        do {
            try await postsRef.addDocument(data: data)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePost(
        _ post: CommunityPost,
        title: String,
        description: String,
        link: String?,
        topics: [Topic],
        editorId: String,
    ) async {
        errorMessage = nil

        guard post.authorId == editorId else {
            errorMessage = String(localized: .communityErrorNotAuthor)
            return
        }

        do {
            try await postsRef.document(post.id).updateData([
                "title": title,
                "description": description,
                "link": (link ?? "") as Any,
                "topics": topics.map(\.rawValue),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePost(_ post: CommunityPost) async {
        do {
            try await postsRef.document(post.id).delete()
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func reportPost(
        _ post: CommunityPost,
        reporterId: String,
        reason: String,
    ) async {
        let docId = "\(reporterId)_\(post.id)"
        do {
            try await db.collection("reports").document(docId).setData([
                "postId": post.id,
                "postTitle": post.title,
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

    func hasReportedPost(
        _ postId: String,
        reporterId: String,
    ) async -> Bool {
        let docId = "\(reporterId)_\(postId)"
        do {
            let snapshot = try await db.collection("reports").document(docId).getDocument()
            return snapshot.exists
        }
        catch {
            return false
        }
    }

    func authorEmoji(for authorId: String) -> String? {
        authorEmojiCache[authorId]
    }

    // generation guards against a stale fetch writing after a newer snapshot
    // arrived: each snapshot bumps authorEmojiFetchGeneration, and a fetch bails
    // out as soon as its captured generation no longer matches.
    private func fetchAuthorEmojis(generation: Int) async {
        let authorIds = Set(posts.map(\.authorId))
        let idsToFetch = authorIds.filter { authorEmojiCache[$0] == nil }
        guard !idsToFetch.isEmpty else { return }

        for uid in idsToFetch {
            guard generation == authorEmojiFetchGeneration else { return }
            do {
                let snapshot = try await db.collection("users").document(uid).getDocument()
                guard generation == authorEmojiFetchGeneration else { return }
                let emoji = (snapshot.data()?["profileEmoji"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                authorEmojiCache[uid] = emoji
            }
            catch {
                guard generation == authorEmojiFetchGeneration else { return }
                authorEmojiCache[uid] = nil
            }
        }
    }

    func deleteUserContent(uid: String) async throws {
        let ownPosts = try await postsRef
            .whereField("authorId", isEqualTo: uid)
            .getDocuments()
        for doc in ownPosts.documents {
            try await doc.reference.delete()
        }

        let likedPosts = try await postsRef
            .whereField("likedBy", arrayContains: uid)
            .getDocuments()
        for doc in likedPosts.documents {
            try await doc.reference.updateData([
                "likedBy": FieldValue.arrayRemove([uid]),
                "likeCount": FieldValue.increment(Int64(-1)),
            ])
        }

        let submittedReports = try await db.collection("reports")
            .whereField("reporterId", isEqualTo: uid)
            .getDocuments()
        for doc in submittedReports.documents {
            try await doc.reference.delete()
        }

        let ownComments = try await db.collectionGroup("comments")
            .whereField("authorId", isEqualTo: uid)
            .getDocuments()
        for doc in ownComments.documents {
            try await doc.reference.delete()
            if let postRef = doc.reference.parent.parent {
                try await postRef.updateData([
                    "commentCount": FieldValue.increment(Int64(-1)),
                ])
            }
        }
    }

    func toggleLike(
        _ post: CommunityPost,
        userId: String,
    ) async {
        let ref = postsRef.document(post.id)
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
            target: .communityPost(post.id),
            preview: post.title)
        if isLiked {
            await activityRecorder.clear(draft)
        }
        else {
            await activityRecorder.set(draft)
        }
    }

    // Takes a `DocumentSnapshot` so both collection queries and single-document
    // reads decode through here; a missing document has no data and yields nil.
    private static func parsePost(_ doc: DocumentSnapshot) -> CommunityPost? {
        guard let data = doc.data() else {
            return nil
        }
        guard let authorId = data["authorId"] as? String,
              let title = data["title"] as? String
        else { return nil }

        let topicStrings = data["topics"] as? [String] ?? []
        let topics = topicStrings.compactMap(Topic.init(rawValue:))
        let likedByArray = data["likedBy"] as? [String] ?? []

        return CommunityPost(
            id: doc.documentID,
            authorId: authorId,
            authorName: data["authorName"] as? String ?? "",
            title: title,
            description: data["description"] as? String ?? "",
            link: (data["link"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            topics: topics,
            likeCount: max(0, data["likeCount"] as? Int ?? 0),
            likedBy: Set(likedByArray),
            commentCount: max(0, data["commentCount"] as? Int ?? 0),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue())
    }
}
