import Foundation

/// One article the reader opened, kept so they can find it again.
///
/// `ReadTracker` stores read state as short hashes, which answers "have I read
/// this" for a row already on screen but cannot name anything. This record is
/// what makes a history list possible: enough to render a row and route back to
/// the article, and nothing more.
struct ReadRecord: Identifiable, Hashable, Codable, Sendable {
    let url: URL
    let title: String
    let sourceName: String
    let readAt: Date

    var id: URL {
        url
    }
}
