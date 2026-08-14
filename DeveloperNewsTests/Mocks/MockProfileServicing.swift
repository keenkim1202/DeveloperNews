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
    var profileBio: String?
    var followedUserIds: Set<String> = []

    private(set) var updatedBios: [String] = []

    var followerCount = 0
    var followingCount = 0
    var userSummaries: [UserSummary] = []
    var followers: [UserSummary] = []
    var following: [UserSummary] = []
    var searchResults: [UserSummary] = []

    private(set) var didStopListening = false
    private(set) var searchedQueries: [String] = []
    private(set) var requestedSummaryIds: [[String]] = []

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

    func updateBio(_ bio: String) async {
        updatedBios.append(bio)
        profileBio = bio
    }

    func fetchFollowerCount(for userId: String) async -> Int {
        followerCount
    }

    func fetchFollowingCount(for userId: String) async -> Int {
        followingCount
    }

    func fetchUserSummaries(for userIds: [String]) async -> [UserSummary] {
        requestedSummaryIds.append(userIds)
        return userSummaries
    }

    func fetchFollowers(of userId: String) async -> [UserSummary] {
        followers
    }

    func fetchFollowing(of userId: String) async -> [UserSummary] {
        following
    }

    func searchUsers(matching query: String) async -> [UserSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        searchedQueries.append(trimmed)
        return searchResults
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
