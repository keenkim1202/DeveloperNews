import Foundation

extension URL {
    /// Builds a URL from a compile-time string literal. Traps with a clear
    /// message if the literal is malformed (a programmer error, not runtime input).
    init(static staticString: StaticString) {
        guard let url = URL(string: "\(staticString)") else {
            preconditionFailure("Invalid static URL literal: \(staticString)")
        }
        self = url
    }
}
