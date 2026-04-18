import CryptoKit
import Foundation

enum HashUtil {
    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func shortHash(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
