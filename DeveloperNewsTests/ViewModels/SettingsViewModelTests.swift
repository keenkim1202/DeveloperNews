import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct SettingsViewModelTests {
    @Test func updateBioTrimsAndDelegatesToService() async {
        let profile = MockProfileServicing()
        let appState = VMFixtures.makeAppState(profile: profile)
        let viewModel = SettingsViewModel(appState: appState)
        viewModel.editingBio = "  Hello world  "

        await viewModel.updateBio()

        #expect(profile.updatedBios == ["Hello world"])
        #expect(profile.profileBio == "Hello world")
    }

    @Test func profileBioReadsFromService() {
        let profile = MockProfileServicing()
        profile.profileBio = "Current bio"
        let appState = VMFixtures.makeAppState(profile: profile)
        let viewModel = SettingsViewModel(appState: appState)

        #expect(viewModel.profileBio == "Current bio")
    }

    @Test func textSizeSelectionReachesTheReader() {
        let appState = VMFixtures.makeAppState()
        let viewModel = SettingsViewModel(appState: appState)
        let item = VMFixtures.makeItem()
        let reader = ArticleDetailViewModel(appState: appState, item: item)

        #expect(viewModel.readerTextSize == .standard)
        #expect(reader.readerTextScale == 1)

        viewModel.setReaderTextSize(.large)

        #expect(viewModel.readerTextSize == .large)
        #expect(reader.readerTextScale == ReaderTextSize.large.scale)
    }

    // The scale multiplies whatever Dynamic Type already decided, so the order
    // of the cases has to hold or the picker reads backwards.
    @Test func textSizesAreOrderedSmallestFirst() {
        let scales = ReaderTextSize.allCases.map(\.scale)

        #expect(scales == scales.sorted())
        #expect(ReaderTextSize.standard.scale == 1)
    }
}
