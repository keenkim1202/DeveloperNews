import FirebaseAuth
import Foundation

@MainActor
protocol ProfileServicing {
    var profile: UserProfile? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    var displayName: String { get }
    var profileEmoji: String? { get }
    var followedUserIds: Set<String> { get }

    func isFollowing(_ userId: String) -> Bool

    func startListening(for user: FirebaseAuth.User)
    func stopListening()

    func createProfileIfNeeded(for user: FirebaseAuth.User) async

    func updateDisplayName(_ name: String) async
    func updateProfileEmoji(_ emoji: String) async

    func fetchFollowerCount(for userId: String) async -> Int
    func fetchFollowingCount(for userId: String) async -> Int

    func fetchUserSummaries(for userIds: [String]) async -> [UserSummary]
    func fetchFollowers(of userId: String) async -> [UserSummary]
    func fetchFollowing(of userId: String) async -> [UserSummary]

    func toggleFollow(_ targetUserId: String) async

    func deleteOwnProfile(uid: String) async throws
}
