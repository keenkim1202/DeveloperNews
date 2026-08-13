import Foundation
@testable import DeveloperNews

@MainActor
final class MockActivityRecording: ActivityRecording {
    private(set) var appended: [ActivityDraft] = []
    private(set) var written: [ActivityDraft] = []
    private(set) var cleared: [ActivityDraft] = []

    func append(_ draft: ActivityDraft) async {
        appended.append(draft)
    }

    func set(_ draft: ActivityDraft) async {
        written.append(draft)
    }

    func clear(_ draft: ActivityDraft) async {
        cleared.append(draft)
    }
}
