import Foundation
import Observation

@Observable
@MainActor
final class PasswordResetViewModel {
    private let appState: AppState
    private var authService: AuthService {
        appState.authService
    }

    init(appState: AppState) {
        self.appState = appState
    }

    var isLoading: Bool {
        authService.isLoading
    }
    var errorMessage: String? {
        authService.errorMessage
    }

    func isEmailFormatValid(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    func canSubmit(email: String) -> Bool {
        isEmailFormatValid(email) && !isLoading
    }

    func clearError() {
        authService.setErrorMessage(nil)
    }

    func sendPasswordReset(email: String) async -> Bool {
        clearError()
        let result = await authService.sendPasswordReset(email: email)
        if case .success = result {
            return true
        }
        return false
    }
}
