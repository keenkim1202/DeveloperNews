import Foundation

struct UserProfile: Codable, Sendable {
    let uid: String
    var displayName: String
    var photoURL: String?
    var profileEmoji: String?
    var followedUserIds: Set<String>
    var createdAt: Date
    var updatedAt: Date
}
