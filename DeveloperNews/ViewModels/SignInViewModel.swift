import Foundation
import Observation

@Observable
@MainActor
final class SignInViewModel {
    private let appState: AppState
    private var authService: AuthService {
        appState.authService
    }

    var email = ""
    var password = ""
    var isSignUp = false
    var hasAgreedToTerms = false
    var showPasswordReset = false
    var showPrivacyPolicy = false
    var showTermsOfUse = false

    init(appState: AppState) {
        self.appState = appState
    }

    var isSignedIn: Bool {
        authService.isSignedIn
    }
    var isLoading: Bool {
        authService.isLoading
    }
    var errorMessage: String? {
        authService.errorMessage
    }

    var isEmailFormatValid: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var showEmailFormatError: Bool {
        !email.isEmpty && !isEmailFormatValid
    }

    var canSubmitEmailForm: Bool {
        guard !email.isEmpty, !password.isEmpty, isEmailFormatValid else { return false }
        if isSignUp {
            return hasAgreedToTerms
        }
        return true
    }

    func signInWithApple() async {
        _ = await authService.signInWithApple()
    }

    func signInWithGoogle() async {
        _ = await authService.signInWithGoogle()
    }

    func submitEmailForm() async {
        if isSignUp {
            _ = await authService.signUpWithEmail(email, password: password)
        } else {
            _ = await authService.signInWithEmail(email, password: password)
        }
    }

    func clearError() {
        authService.setErrorMessage(nil)
    }

    func toggleMode() {
        clearError()
        isSignUp.toggle()
    }

    func openPasswordReset() {
        clearError()
        showPasswordReset = true
    }
}
