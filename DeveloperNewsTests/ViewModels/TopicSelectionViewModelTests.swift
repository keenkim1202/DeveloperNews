import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct TopicSelectionViewModelTests {
    @Test func toggleAddsAndRemovesTopic() async {
        let appState = VMFixtures.makeAppState()
        let vm = TopicSelectionViewModel(appState: appState)

        #expect(vm.selectedCount == 0)
        vm.toggleTopic(.ios)
        #expect(vm.selectedTopics.contains(.ios))
        #expect(vm.selectedCount == 1)

        vm.toggleTopic(.ios)
        #expect(!vm.selectedTopics.contains(.ios))
        #expect(vm.selectedCount == 0)
    }

    @Test func canSelectMoreReflectsLimit() async {
        let appState = VMFixtures.makeAppState()
        let vm = TopicSelectionViewModel(appState: appState)

        let allTopics = Topic.allCases.prefix(vm.maxSelectedTopics)
        for topic in allTopics {
            vm.toggleTopic(topic)
        }

        #expect(vm.selectedCount == vm.maxSelectedTopics)
        #expect(!vm.canSelectMore)
    }

    @Test func toggleBeyondLimitIsIgnored() async {
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
            #expect(!vm.selectedTopics.contains(extra))
        }
        #expect(vm.selectedCount == countAtLimit)
    }
}
