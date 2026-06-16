import FirebaseAuth
import Foundation

@MainActor
protocol AuthServicing {
    var user: FirebaseAuth.User? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    var isSignedIn: Bool { get }
    var userId: String? { get }
    var displayName: String? { get }
    var email: String? { get }
    var photoURL: URL? { get }

    @discardableResult
    func signInWithApple() async -> Bool

    @discardableResult
    func signInWithGoogle() async -> Bool

    @discardableResult
    func signInWithEmail(
        _ email: String,
        password: String,
    ) async -> Bool

    @discardableResult
    func signUpWithEmail(
        _ email: String,
        password: String,
    ) async -> Bool

    @discardableResult
    func sendPasswordReset(email: String) async -> PasswordResetResult

    func signOut()

    func setErrorMessage(_ message: String?)

    @discardableResult
    func deleteAccount() async -> DeleteAccountResult
}
