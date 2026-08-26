import Foundation

/// One article the reader opened, kept so they can find it again.
///
/// `ReadTracker` stores short hashes, which answer "have I read this" for a row
/// on screen but name nothing. This is the least a history list needs.
struct ReadRecord: Identifiable, Hashable, Codable, Sendable {
    let url: URL
    let title: String
    let sourceName: String
    let readAt: Date

    var id: URL {
        url
    }
}
