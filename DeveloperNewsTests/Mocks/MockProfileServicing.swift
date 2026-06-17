import FirebaseAuth
import Foundation
@testable import DeveloperNews

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
    var userSummaries: [UserSummary] = []
    var followers: [UserSummary] = []
    var following: [UserSummary] = []

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

    func fetchUserSummaries(for userIds: [String]) async -> [UserSummary] {
        userSummaries
    }

    func fetchFollowers(of userId: String) async -> [UserSummary] {
        followers
    }

    func fetchFollowing(of userId: String) async -> [UserSummary] {
        following
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
