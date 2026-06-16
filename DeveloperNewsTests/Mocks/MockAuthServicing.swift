import FirebaseAuth
import Foundation
@testable import DeveloperNews

// Mock conformance to AuthServicing returning canned values. The FirebaseAuth
// User type cannot be constructed in a unit test, so `user` stays nil while the
// derived identity values are backed by stored properties.
@MainActor
final class MockAuthServicing: AuthServicing {
    var user: FirebaseAuth.User? = nil
    var isLoading = false
    var errorMessage: String?

    var isSignedIn = false
    var userId: String?
    var displayName: String?
    var email: String?
    var photoURL: URL?

    var signInWithAppleResult = true
    var signInWithGoogleResult = true
    var signInWithEmailResult = true
    var signUpWithEmailResult = true
    var sendPasswordResetResult: PasswordResetResult = .success
    var deleteAccountResult: DeleteAccountResult = .success

    private(set) var didSignOut = false

    init(
        userId: String? = nil,
        displayName: String? = nil,
    ) {
        self.userId = userId
        self.displayName = displayName
        self.isSignedIn = userId != nil
    }

    @discardableResult
    func signInWithApple() async -> Bool {
        signInWithAppleResult
    }

    @discardableResult
    func signInWithGoogle() async -> Bool {
        signInWithGoogleResult
    }

    @discardableResult
    func signInWithEmail(
        _ email: String,
        password: String,
    ) async -> Bool {
        signInWithEmailResult
    }

    @discardableResult
    func signUpWithEmail(
        _ email: String,
        password: String,
    ) async -> Bool {
        signUpWithEmailResult
    }

    @discardableResult
    func sendPasswordReset(email: String) async -> PasswordResetResult {
        sendPasswordResetResult
    }

    func signOut() {
        didSignOut = true
        isSignedIn = false
    }

    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }

    @discardableResult
    func deleteAccount() async -> DeleteAccountResult {
        deleteAccountResult
    }
}
