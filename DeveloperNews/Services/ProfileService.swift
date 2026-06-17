import FirebaseAuth
import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class ProfileService: ProfileServicing {
    private(set) var profile: UserProfile?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var currentUser: FirebaseAuth.User?
    private var profileCreationInFlight = false

    var displayName: String {
        if let name = profile?.displayName, !name.isEmpty {
            return name
        }
        return currentUser?.displayName ?? ""
    }

    var profileEmoji: String? {
        profile?.profileEmoji
    }

    var followedUserIds: Set<String> {
        profile?.followedUserIds ?? []
    }

    func isFollowing(_ userId: String) -> Bool {
        followedUserIds.contains(userId)
    }

    func startListening(for user: FirebaseAuth.User) {
        stopListening()
        currentUser = user

        let ref = db.collection("users").document(user.uid)
        listenerRegistration = ref.addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let data = snapshot?.data(), snapshot?.exists == true else {
                    self.profile = nil
                    return
                }
                let followedArray = data["followedUserIds"] as? [String] ?? []
                self.profile = UserProfile(
                    uid: user.uid,
                    displayName: data["displayName"] as? String ?? "",
                    photoURL: data["photoURL"] as? String,
                    profileEmoji: data["profileEmoji"] as? String,
                    followedUserIds: Set(followedArray),
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date())
            }
        }
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        profile = nil
        currentUser = nil
    }

    func createProfileIfNeeded(for user: FirebaseAuth.User) async {
        guard !profileCreationInFlight else { return }
        profileCreationInFlight = true
        defer { profileCreationInFlight = false }

        let ref = db.collection("users").document(user.uid)

        do {
            let snapshot = try await ref.getDocument()
            if snapshot.exists {
                return
            }

            let now = FieldValue.serverTimestamp()
            try await ref.setData([
                "displayName": user.displayName ?? "",
                "photoURL": user.photoURL?.absoluteString ?? "",
                "followedUserIds": [String](),
                "createdAt": now,
                "updatedAt": now,
            ])
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateDisplayName(_ name: String) async {
        guard let uid = currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await db.collection("users").document(uid).setData([
                "displayName": name,
                "updatedAt": FieldValue.serverTimestamp(),
            ], merge: true)
            await updateAuthorFieldInPosts(uid: uid, field: "authorName", value: name)
        }
        catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateProfileEmoji(_ emoji: String) async {
        guard let uid = currentUser?.uid else { return }

        do {
            try await db.collection("users").document(uid).setData([
                "profileEmoji": emoji,
                "updatedAt": FieldValue.serverTimestamp(),
            ], merge: true)
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchFollowerCount(for userId: String) async -> Int {
        do {
            let snapshot = try await db.collection("users")
                .whereField("followedUserIds", arrayContains: userId)
                .getDocuments()
            return snapshot.documents.count
        }
        catch {
            return 0
        }
    }

    func fetchFollowingCount(for userId: String) async -> Int {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            let data = snapshot.data() ?? [:]
            let followedArray = data["followedUserIds"] as? [String] ?? []
            return followedArray.count
        }
        catch {
            return 0
        }
    }

    func fetchUserSummaries(for userIds: [String]) async -> [UserSummary] {
        var summaries: [UserSummary] = []
        for id in userIds {
            do {
                let snapshot = try await db.collection("users").document(id).getDocument()
                guard let data = snapshot.data() else { continue }
                summaries.append(UserSummary(
                    id: id,
                    displayName: data["displayName"] as? String ?? "",
                    emoji: (data["profileEmoji"] as? String).flatMap { $0.isEmpty ? nil : $0 }))
            }
            catch {
                continue
            }
        }
        return summaries
    }

    func fetchFollowers(of userId: String) async -> [UserSummary] {
        do {
            let snapshot = try await db.collection("users")
                .whereField("followedUserIds", arrayContains: userId)
                .getDocuments()
            return snapshot.documents.map { doc in
                let data = doc.data()
                return UserSummary(
                    id: doc.documentID,
                    displayName: data["displayName"] as? String ?? "",
                    emoji: (data["profileEmoji"] as? String).flatMap { $0.isEmpty ? nil : $0 })
            }
        }
        catch {
            return []
        }
    }

    func fetchFollowing(of userId: String) async -> [UserSummary] {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            let followedArray = (snapshot.data()?["followedUserIds"] as? [String]) ?? []
            return await fetchUserSummaries(for: followedArray)
        }
        catch {
            return []
        }
    }

    private func updateAuthorFieldInPosts(
        uid: String,
        field: String,
        value: String,
    ) async {
        do {
            let snapshot = try await db.collection("posts")
                .whereField("authorId", isEqualTo: uid)
                .getDocuments()

            for doc in snapshot.documents {
                try await doc.reference.updateData([field: value])
            }
        }
        catch {
            // Best effort — don't block profile update
        }
    }

    func toggleFollow(_ targetUserId: String) async {
        guard let uid = currentUser?.uid else { return }

        let ref = db.collection("users").document(uid)
        let isCurrentlyFollowing = followedUserIds.contains(targetUserId)

        do {
            if isCurrentlyFollowing {
                try await ref.updateData([
                    "followedUserIds": FieldValue.arrayRemove([targetUserId]),
                ])
            }
            else {
                try await ref.setData([
                    "followedUserIds": FieldValue.arrayUnion([targetUserId]),
                ], merge: true)
            }
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteOwnProfile(uid: String) async throws {
        try await db.collection("users").document(uid).delete()
        stopListening()
    }
}
