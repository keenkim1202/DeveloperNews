import Foundation

/// A reason a user can give when reporting a community post.
/// `storageValue` is the string persisted to the reports collection; it is kept
/// byte-compatible with the previously hand-written reason strings.
enum ReportReason: Equatable {
    case spam
    case inappropriate
    case other(String)

    var storageValue: String {
        switch self {
        case .spam:
            "spam"
        case .inappropriate:
            "inappropriate"
        case let .other(detail):
            "other: \(detail)"
        }
    }
}
