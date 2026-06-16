import XCTest
@testable import DeveloperNews

@MainActor
final class TopicSelectionViewModelTests: XCTestCase {
    func testToggleAddsAndRemovesTopic() async {
        let appState = VMFixtures.makeAppState()
        let vm = TopicSelectionViewModel(appState: appState)

        XCTAssertEqual(vm.selectedCount, 0)
        vm.toggleTopic(.ios)
        XCTAssertTrue(vm.selectedTopics.contains(.ios))
        XCTAssertEqual(vm.selectedCount, 1)

        vm.toggleTopic(.ios)
        XCTAssertFalse(vm.selectedTopics.contains(.ios))
        XCTAssertEqual(vm.selectedCount, 0)
    }

    func testCanSelectMoreReflectsLimit() async {
        let appState = VMFixtures.makeAppState()
        let vm = TopicSelectionViewModel(appState: appState)

        let allTopics = Topic.allCases.prefix(vm.maxSelectedTopics)
        for topic in allTopics {
            vm.toggleTopic(topic)
        }

        XCTAssertEqual(vm.selectedCount, vm.maxSelectedTopics)
        XCTAssertFalse(vm.canSelectMore)
    }

    func testToggleBeyondLimitIsIgnored() async {
        let appState = VMFixtures.makeAppState()
        let vm = TopicSelectionViewModel(appState: appState)

        let limited = Topic.allCases.prefix(vm.maxSelectedTopics)
        for topic in limited {
            vm.toggleTopic(topic)
        }
        let countAtLimit = vm.selectedCount

        // Pick a topic not already selected and confirm it cannot be added.
        if let extra = Topic.allCases.first(where: { !vm.selectedTopics.contains($0) }) {
            vm.toggleTopic(extra)
            XCTAssertFalse(vm.selectedTopics.contains(extra))
        }
        XCTAssertEqual(vm.selectedCount, countAtLimit)
    }
}
