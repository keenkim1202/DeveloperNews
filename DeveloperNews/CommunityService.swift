import FirebaseAuth
import FirebaseFirestore
import Foundation

struct CommunityPost: Identifiable, Hashable {
    let id: String
    let authorId: String
    let authorName: String
    let title: String
    let description: String
    let link: String?
    let topics: [Topic]
    let likeCount: Int
    let likedBy: Set<String>
    let createdAt: Date
    let updatedAt: Date?

    var hasLink: Bool {
        guard let link, !link.isEmpty else { return false }
        return URL(string: link) != nil
    }

    var linkURL: URL? {
        guard let link else { return nil }
        return URL(string: link)
    }
}

@Observable
final class CommunityService {
    private(set) var posts: [CommunityPost] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var authorEmojiCache: [String: String] = [:]

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    private var postsRef: CollectionReference {
        db.collection("posts")
    }

    func startListening() {
        stopListening()
        isLoading = true

        listenerRegistration = postsRef
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
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
                Task { await self.fetchAuthorEmojis() }
            }
    }

    func refresh() async {
        do {
            let snapshot = try await postsRef
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            posts = snapshot.documents.compactMap { Self.parsePost($0) }
            await fetchAuthorEmojis()
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
    }

    func createPost(title: String, description: String, link: String?, topics: [Topic], author: FirebaseAuth.User, authorDisplayName: String) async {
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
            "createdAt": FieldValue.serverTimestamp(),
        ]

        do {
            try await postsRef.addDocument(data: data)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePost(_ post: CommunityPost, title: String, description: String, link: String?, topics: [Topic], editorId: String) async {
        errorMessage = nil

        guard post.authorId == editorId else {
            errorMessage = String(localized: "community.error.notAuthor")
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

    func reportPost(_ post: CommunityPost, reporterId: String, reason: String) async {
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

    func hasReportedPost(_ postId: String, reporterId: String) async -> Bool {
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

    private func fetchAuthorEmojis() async {
        let authorIds = Set(posts.map(\.authorId))
        let idsToFetch = authorIds.filter { authorEmojiCache[$0] == nil }
        guard !idsToFetch.isEmpty else { return }

        let db = self.db
        let fetched = await withTaskGroup(of: (String, String?).self) { group in
            for uid in idsToFetch {
                group.addTask {
                    do {
                        let snapshot = try await db.collection("users").document(uid).getDocument()
                        let emoji = (snapshot.data()?["profileEmoji"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                        return (uid, emoji)
                    }
                    catch {
                        return (uid, nil)
                    }
                }
            }

            var results: [(String, String?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        for (uid, emoji) in fetched {
            authorEmojiCache[uid] = emoji
        }
    }

    func filteredPosts(excludingUserIds blockedIds: Set<String>) -> [CommunityPost] {
        guard !blockedIds.isEmpty else { return posts }
        return posts.filter { !blockedIds.contains($0.authorId) }
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
    }

    func toggleLike(_ post: CommunityPost, userId: String) async {
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
        }
    }

    private static func parsePost(_ doc: QueryDocumentSnapshot) -> CommunityPost? {
        let data = doc.data()
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
            likeCount: data["likeCount"] as? Int ?? 0,
            likedBy: Set(likedByArray),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
