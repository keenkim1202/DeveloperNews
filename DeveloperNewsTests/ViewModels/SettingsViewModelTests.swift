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
}
