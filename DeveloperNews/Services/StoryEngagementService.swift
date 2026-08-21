@preconcurrency import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class StoryEngagementService: StoryEngagementServicing {
    private(set) var errorMessage: String?
    private(set) var engagement: StoryEngagement?

    private let db = Firestore.firestore()

    // Firestore caps `in` queries (including `FieldPath.documentID()`) at 10
    // values per request, so batched reads are chunked to stay within that.
    private static let inQueryChunkSize = 10

    // Upper bound on URLs a single batched fetch will resolve, so a large list
    // never fans out into an unbounded number of queries.
    private static let maxBatchedURLs = 30

    // UserDefaults key holding a [docId: yyyy-MM-dd] map used to count a view at
    // most once per device per calendar day.
    private static let viewedDaysKey = "storyEngagement.viewedDays"

    // Non-localized formatter so the day key is stable regardless of locale.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @ObservationIgnored
    nonisolated(unsafe) private var listenerRegistration: ListenerRegistration?

    deinit {
        listenerRegistration?.remove()
    }

    private var engagementRef: CollectionReference {
        db.collection("storyEngagement")
    }

    func startListening(storyURL: String) {
        stopListening()

        let docId = StoryEngagement.documentId(for: storyURL)
        listenerRegistration = engagementRef.document(docId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.engagement = Self.parseEngagement(snapshot)
                }
            }
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        engagement = nil
    }

    func ensureDocument(storyURL: String) async {
        errorMessage = nil
        do {
            try await Self.createIfMissing(db, storyURL: storyURL)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(
        storyURL: String,
        userId: String,
    ) async {
        errorMessage = nil
        do {
            try await Self.runToggleLike(db, storyURL: storyURL, userId: userId)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchEngagement(storyURL: String) async -> StoryEngagement? {
        let docId = StoryEngagement.documentId(for: storyURL)
        do {
            let snapshot = try await engagementRef.document(docId).getDocument()
            return Self.parseEngagement(snapshot)
        }
        catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func fetchEngagements(storyURLs: [String]) async -> [String: StoryEngagement] {
        let uniqueURLs = Array(Set(storyURLs))
        guard !uniqueURLs.isEmpty else {
            return [:]
        }

        var cappedURLs = uniqueURLs
        if cappedURLs.count > Self.maxBatchedURLs {
            // Truncating instead of fanning out keeps list rendering bounded;
            // callers asking for more than this should page their requests.
            cappedURLs = Array(cappedURLs.prefix(Self.maxBatchedURLs))
        }

        // Map every requested doc id back to its URL so results can be keyed by
        // the URL the caller passed in rather than the opaque hash.
        var urlByDocId: [String: String] = [:]
        for url in cappedURLs {
            urlByDocId[StoryEngagement.documentId(for: url)] = url
        }
        let docIds = Array(urlByDocId.keys)

        var result: [String: StoryEngagement] = [:]
        do {
            for chunk in docIds.chunked(into: Self.inQueryChunkSize) {
                let snapshot = try await engagementRef
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snapshot.documents {
                    guard let engagement = Self.parseEngagement(doc),
                          let url = urlByDocId[doc.documentID]
                    else { continue }
                    result[url] = engagement
                }
            }
        }
        catch {
            errorMessage = error.localizedDescription
            return result
        }

        return result
    }

    // Counts a view at most once per device per calendar day, with the dedup map
    // in UserDefaults. The marker is set only on success, so a failed write
    // retries on a later session or day.
    func registerView(storyURL: String) async {
        errorMessage = nil

        let docId = StoryEngagement.documentId(for: storyURL)
        let today = Self.dayFormatter.string(from: Date())

        let defaults = UserDefaults.standard
        let viewedDays = defaults.dictionary(forKey: Self.viewedDaysKey) as? [String: String] ?? [:]

        if viewedDays[docId] == today {
            return
        }

        do {
            try await Self.incrementViewCount(db, storyURL: storyURL)

            // Re-read after the await: writing back the pre-await snapshot would
            // drop a marker another story wrote meanwhile and count it twice.
            // The filter also keeps the map from growing past today.
            var updated = (defaults.dictionary(forKey: Self.viewedDaysKey) as? [String: String] ?? [:])
                .filter { _, day in
                    day == today
                }
            updated[docId] = today
            defaults.set(updated, forKey: Self.viewedDaysKey)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    // nonisolated so the transaction closure captures only the local Firestore
    // handle and story values rather than MainActor-isolated `self`.
    nonisolated private static func createIfMissing(
        _ db: Firestore,
        storyURL: String,
    ) async throws {
        let docId = StoryEngagement.documentId(for: storyURL)
        let docRef = db.collection("storyEngagement").document(docId)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(docRef)
            }
            catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            // Only seed when absent; never overwrite live counts.
            guard !snapshot.exists else {
                return nil
            }

            transaction.setData([
                "storyURL": storyURL,
                "likeCount": 0,
                "likedBy": [String](),
                "commentCount": 0,
                "viewCount": 0,
            ], forDocument: docRef)
            return nil
        }
    }

    nonisolated private static func runToggleLike(
        _ db: Firestore,
        storyURL: String,
        userId: String,
    ) async throws {
        let docId = StoryEngagement.documentId(for: storyURL)
        let docRef = db.collection("storyEngagement").document(docId)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(docRef)
            }
            catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            guard snapshot.exists else {
                // First like also creates the document.
                transaction.setData([
                    "storyURL": storyURL,
                    "likeCount": 1,
                    "likedBy": [userId],
                    "commentCount": 0,
                    "viewCount": 0,
                ], forDocument: docRef)
                return nil
            }

            let data = snapshot.data() ?? [:]
            let likedBy = data["likedBy"] as? [String] ?? []
            let currentCount = data["likeCount"] as? Int ?? 0

            if likedBy.contains(userId) {
                transaction.updateData([
                    "likedBy": FieldValue.arrayRemove([userId]),
                    "likeCount": max(0, currentCount - 1),
                ], forDocument: docRef)
            }
            else {
                transaction.updateData([
                    "likedBy": FieldValue.arrayUnion([userId]),
                    "likeCount": max(0, currentCount) + 1,
                ], forDocument: docRef)
            }
            return nil
        }
    }

    nonisolated private static func incrementViewCount(
        _ db: Firestore,
        storyURL: String,
    ) async throws {
        let docId = StoryEngagement.documentId(for: storyURL)
        let docRef = db.collection("storyEngagement").document(docId)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(docRef)
            }
            catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            guard snapshot.exists else {
                // First view also creates the document.
                transaction.setData([
                    "storyURL": storyURL,
                    "likeCount": 0,
                    "likedBy": [String](),
                    "commentCount": 0,
                    "viewCount": 1,
                ], forDocument: docRef)
                return nil
            }

            let data = snapshot.data() ?? [:]
            let currentCount = data["viewCount"] as? Int ?? 0
            transaction.updateData([
                "viewCount": currentCount + 1,
            ], forDocument: docRef)
            return nil
        }
    }

    private static func parseEngagement(_ snapshot: DocumentSnapshot?) -> StoryEngagement? {
        guard let snapshot, snapshot.exists,
              let data = snapshot.data(),
              let storyURL = data["storyURL"] as? String
        else { return nil }

        let likedByArray = data["likedBy"] as? [String] ?? []
        return StoryEngagement(
            id: snapshot.documentID,
            storyURL: storyURL,
            likeCount: max(0, data["likeCount"] as? Int ?? 0),
            likedBy: Set(likedByArray),
            commentCount: max(0, data["commentCount"] as? Int ?? 0),
            viewCount: max(0, data["viewCount"] as? Int ?? 0))
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
