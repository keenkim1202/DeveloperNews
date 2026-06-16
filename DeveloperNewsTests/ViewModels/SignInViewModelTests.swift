import XCTest
@testable import DeveloperNews

@MainActor
final class SignInViewModelTests: XCTestCase {
    private func makeViewModel(auth: MockAuthServicing = MockAuthServicing()) -> SignInViewModel {
        SignInViewModel(appState: VMFixtures.makeAppState(auth: auth))
    }

    func testEmailFormatValidForWellFormedAddress() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        XCTAssertTrue(vm.isEmailFormatValid)
        XCTAssertFalse(vm.showEmailFormatError)
    }

    func testEmailFormatInvalidForMalformedAddress() async {
        let vm = makeViewModel()
        vm.email = "user@@example"
        XCTAssertFalse(vm.isEmailFormatValid)
        XCTAssertTrue(vm.showEmailFormatError)
    }

    func testShowEmailFormatErrorFalseWhenEmpty() async {
        let vm = makeViewModel()
        vm.email = ""
        XCTAssertFalse(vm.showEmailFormatError)
    }

    func testCannotSubmitWithoutPassword() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        vm.password = ""
        XCTAssertFalse(vm.canSubmitEmailForm)
    }

    func testCannotSubmitWithInvalidEmail() async {
        let vm = makeViewModel()
        vm.email = "not-an-email"
        vm.password = "secret123"
        XCTAssertFalse(vm.canSubmitEmailForm)
    }

    func testCanSubmitSignInWithValidCredentials() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        vm.password = "secret123"
        vm.isSignUp = false
        XCTAssertTrue(vm.canSubmitEmailForm)
    }

    func testSignUpRequiresTermsAgreement() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        vm.password = "secret123"
        vm.isSignUp = true
        vm.hasAgreedToTerms = false
        XCTAssertFalse(vm.canSubmitEmailForm)

        vm.hasAgreedToTerms = true
        XCTAssertTrue(vm.canSubmitEmailForm)
    }

    func testToggleModeFlipsSignUpAndClearsError() async {
        let auth = MockAuthServicing()
        auth.errorMessage = "boom"
        let vm = makeViewModel(auth: auth)

        XCTAssertFalse(vm.isSignUp)
        vm.toggleMode()
        XCTAssertTrue(vm.isSignUp)
        XCTAssertNil(vm.errorMessage)
    }

    func testOpenPasswordResetClearsErrorAndShowsSheet() async {
        let auth = MockAuthServicing()
        auth.errorMessage = "boom"
        let vm = makeViewModel(auth: auth)

        vm.openPasswordReset()
        XCTAssertTrue(vm.showPasswordReset)
        XCTAssertNil(vm.errorMessage)
    }
}
