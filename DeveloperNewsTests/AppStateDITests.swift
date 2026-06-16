import XCTest
@testable import DeveloperNews

// Proves protocol-based dependency injection works in tests: AppState is built
// entirely from mock services and the assertions observe values that flow back
// out through the injected dependencies.
@MainActor
final class AppStateDITests: XCTestCase {
    private func makeAppState(
        auth: MockAuthServicing,
        profile: MockProfileServicing = MockProfileServicing(),
        community: MockCommunityServicing = MockCommunityServicing(),
        translator: MockTranslating = MockTranslating(),
    ) -> AppState {
        AppState(
            translator: translator,
            authService: auth,
            profileService: profile,
            communityService: community)
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

    func testDeleteCurrentAccountFailsWithoutSignedInUser() async {
        let auth = MockAuthServicing(userId: nil)
        let state = makeAppState(auth: auth)

        let result = await state.deleteCurrentAccount()

        XCTAssertTrue(isFailed(result))
    }

    func testDeleteCurrentAccountSucceedsWithInjectedMocks() async {
        let auth = MockAuthServicing(userId: "user-123")
        auth.deleteAccountResult = .success
        let profile = MockProfileServicing()
        let state = makeAppState(auth: auth, profile: profile)

        let result = await state.deleteCurrentAccount()

        XCTAssertTrue(isSuccess(result))
        XCTAssertTrue(profile.didStopListening)
    }

    func testSignOutRoutesThroughInjectedServices() async {
        let auth = MockAuthServicing(userId: "user-123")
        let profile = MockProfileServicing()
        let state = makeAppState(auth: auth, profile: profile)

        state.signOut()

        XCTAssertTrue(auth.didSignOut)
        XCTAssertTrue(profile.didStopListening)

        // Let the AppState-owned persistence task settle before this scope
        // releases the instance, so teardown does not race a pending Task.
        await Task.yield()
    }

    func testUpdateDisplayNameForwardsToProfileMock() async {
        let auth = MockAuthServicing(userId: "user-123")
        let profile = MockProfileServicing()
        let state = makeAppState(auth: auth, profile: profile)

        await state.updateDisplayName("Renamed")

        XCTAssertEqual(profile.displayName, "Renamed")
    }
}
