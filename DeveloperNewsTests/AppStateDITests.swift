import Testing
import Foundation
@testable import DeveloperNews

// Proves protocol-based dependency injection works in tests: AppState is built
// entirely from mock services and the assertions observe values that flow back
// out through the injected dependencies.
@MainActor
@Suite struct AppStateDITests {
    private func makeAppState(
        auth: MockAuthServicing,
        profile: MockProfileServicing = MockProfileServicing(),
        community: MockCommunityServicing = MockCommunityServicing(),
        feedPost: MockFeedPostServicing = MockFeedPostServicing(),
        translator: MockTranslating = MockTranslating(),
    ) -> AppState {
        AppState(
            translator: translator,
            authService: auth,
            profileService: profile,
            communityService: community,
            feedPostService: feedPost,
            persistenceStore: VMFixtures.makeIsolatedPersistenceStore())
    }

    private func isFailed(_ result: DeleteAccountResult) -> Bool {
        if case .failed = result {
            return true
        }
        return false
    }

    private func isSuccess(_ result: DeleteAccountResult) -> Bool {
        if case .success = result {
            return true
        }
        return false
    }

    @Test func deleteCurrentAccountFailsWithoutSignedInUser() async {
        let auth = MockAuthServicing(userId: nil)
        let state = makeAppState(auth: auth)

        let result = await state.deleteCurrentAccount()

        #expect(isFailed(result))
    }

    @Test func deleteCurrentAccountSucceedsWithInjectedMocks() async {
        let auth = MockAuthServicing(userId: "user-123")
        auth.deleteAccountResult = .success
        let profile = MockProfileServicing()
        let state = makeAppState(auth: auth, profile: profile)

        let result = await state.deleteCurrentAccount()

        #expect(isSuccess(result))
        #expect(profile.didStopListening)
    }

    @Test func signOutRoutesThroughInjectedServices() async {
        let auth = MockAuthServicing(userId: "user-123")
        let profile = MockProfileServicing()
        let state = makeAppState(auth: auth, profile: profile)

        state.signOut()

        #expect(auth.didSignOut)
        #expect(profile.didStopListening)
    }

    @Test func updateDisplayNameForwardsToProfileMock() async {
        let auth = MockAuthServicing(userId: "user-123")
        let profile = MockProfileServicing()
        let state = makeAppState(auth: auth, profile: profile)

        await state.updateDisplayName("Renamed")

        #expect(profile.displayName == "Renamed")
    }
}
