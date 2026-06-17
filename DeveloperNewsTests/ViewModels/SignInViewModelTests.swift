import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct SignInViewModelTests {
    private func makeViewModel(auth: MockAuthServicing = MockAuthServicing()) -> SignInViewModel {
        SignInViewModel(appState: VMFixtures.makeAppState(auth: auth))
    }

    @Test func emailFormatValidForWellFormedAddress() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        #expect(vm.isEmailFormatValid)
        #expect(!vm.showEmailFormatError)
    }

    @Test func emailFormatInvalidForMalformedAddress() async {
        let vm = makeViewModel()
        vm.email = "user@@example"
        #expect(!vm.isEmailFormatValid)
        #expect(vm.showEmailFormatError)
    }

    @Test func showEmailFormatErrorFalseWhenEmpty() async {
        let vm = makeViewModel()
        vm.email = ""
        #expect(!vm.showEmailFormatError)
    }

    @Test func cannotSubmitWithoutPassword() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        vm.password = ""
        #expect(!vm.canSubmitEmailForm)
    }

    @Test func cannotSubmitWithInvalidEmail() async {
        let vm = makeViewModel()
        vm.email = "not-an-email"
        vm.password = "secret123"
        #expect(!vm.canSubmitEmailForm)
    }

    @Test func canSubmitSignInWithValidCredentials() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        vm.password = "secret123"
        vm.isSignUp = false
        #expect(vm.canSubmitEmailForm)
    }

    @Test func signUpRequiresTermsAgreement() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        vm.password = "secret123"
        vm.isSignUp = true
        vm.hasAgreedToTerms = false
        #expect(!vm.canSubmitEmailForm)

        vm.hasAgreedToTerms = true
        #expect(vm.canSubmitEmailForm)
    }

    @Test func toggleModeFlipsSignUpAndClearsError() async {
        let auth = MockAuthServicing()
        auth.errorMessage = "boom"
        let vm = makeViewModel(auth: auth)

        #expect(!vm.isSignUp)
        vm.toggleMode()
        #expect(vm.isSignUp)
        #expect(vm.errorMessage == nil)
    }

    @Test func openPasswordResetClearsErrorAndShowsSheet() async {
        let auth = MockAuthServicing()
        auth.errorMessage = "boom"
        let vm = makeViewModel(auth: auth)

        vm.openPasswordReset()
        #expect(vm.showPasswordReset)
        #expect(vm.errorMessage == nil)
    }
}
