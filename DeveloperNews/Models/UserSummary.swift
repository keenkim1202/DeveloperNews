import Foundation

struct UserSummary: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let emoji: String?
    let bio: String?
}
