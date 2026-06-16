import FirebaseAuth
import Foundation
@testable import DeveloperNews

// Mock conformance to ProfileServicing returning canned values.
@MainActor
final class MockProfileServicing: ProfileServicing {
    var profile: UserProfile?
    var isLoading = false
    var errorMessage: String?

    var displayName = "Mock User"
    var profileEmoji: String?
    var followedUserIds: Set<String> = []

    var followerCount = 0
    var followingCount = 0

    private(set) var didStopListening = false

    func isFollowing(_ userId: String) -> Bool {
        followedUserIds.contains(userId)
    }

    func startListening(for user: FirebaseAuth.User) {
    }

    func stopListening() {
        didStopListening = true
    }

    func createProfileIfNeeded(for user: FirebaseAuth.User) async {
    }

    func updateDisplayName(_ name: String) async {
        displayName = name
    }

    func updateProfileEmoji(_ emoji: String) async {
        profileEmoji = emoji
    }

    func fetchFollowerCount(for userId: String) async -> Int {
        followerCount
    }

    func fetchFollowingCount(for userId: String) async -> Int {
        followingCount
    }

    func toggleFollow(_ targetUserId: String) async {
        if followedUserIds.contains(targetUserId) {
            followedUserIds.remove(targetUserId)
        }
        else {
            followedUserIds.insert(targetUserId)
        }
    }

    func deleteOwnProfile(uid: String) async throws {
    }
}
