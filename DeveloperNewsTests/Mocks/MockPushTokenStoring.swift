import Foundation
@testable import DeveloperNews

@MainActor
final class MockPushTokenStoring: PushTokenStoring {
    private(set) var saved: [(token: String, userId: String)] = []
    private(set) var removed: [(token: String, userId: String)] = []

    func save(_ token: String, userId: String) async {
        saved.append((token, userId))
    }

    func remove(_ token: String, userId: String) async {
        removed.append((token, userId))
    }
}
