import AuthenticationServices
@preconcurrency import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn

@Observable
@MainActor
final class AuthService: AuthServicing {
    private(set) var user: FirebaseAuth.User?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var currentNonce: String?
    @ObservationIgnored
    nonisolated(unsafe) private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isSignedIn: Bool {
        user != nil
    }
    var userId: String? {
        user?.uid
    }

    var displayName: String? {
        user?.displayName
    }
    var email: String? {
        user?.email
    }
    var photoURL: URL? {
        user?.photoURL
    }

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.user = user
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Apple Sign In

    @discardableResult
    func signInWithApple() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            currentNonce = nil
            appleSignInDelegate = nil
        }

        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        do {
            let result = try await performAppleSignIn(request: request)
            guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8),
                  let storedNonce = currentNonce
            else {
                throw AuthError.invalidCredential
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: storedNonce,
                fullName: appleIDCredential.fullName)

            let authResult = try await Auth.auth().signIn(with: credential)
            return authResult.additionalUserInfo?.isNewUser ?? false
        }
        catch {
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                // User canceled
            }
            else {
                errorMessage = await localizedAuthError(from: error, attemptedEmail: nil)
            }
            return false
        }
    }

    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            appleSignInDelegate = delegate
            controller.delegate = delegate
            controller.performRequests()
        }
    }

    private var appleSignInDelegate: AppleSignInDelegate?

    // MARK: - Google Sign In

    @discardableResult
    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthError.missingClientID
            }

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController
            else {
                throw AuthError.missingRootViewController
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidCredential
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString)

            let authResult = try await Auth.auth().signIn(with: credential)
            return authResult.additionalUserInfo?.isNewUser ?? false
        }
        catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                // User canceled — not an error
            }
            else {
                errorMessage = await localizedAuthError(from: error, attemptedEmail: nil)
            }
            return false
        }
    }

    // MARK: - Email / Password

    @discardableResult
    func signInWithEmail(
        _ email: String,
        password: String,
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            return false
        }
        catch {
            errorMessage = await localizedAuthError(from: error, attemptedEmail: email)
            return false
        }
    }

    @discardableResult
    func signUpWithEmail(
        _ email: String,
        password: String,
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
            return true
        }
        catch {
            errorMessage = await localizedAuthError(from: error, attemptedEmail: email)
            return false
        }
    }

    // MARK: - Password Reset

    @discardableResult
    func sendPasswordReset(email: String) async -> PasswordResetResult {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return .success
        }
        catch {
            let message = await localizedAuthError(from: error, attemptedEmail: email)
            errorMessage = message
            return .failed(message)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        }
        catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }

    @discardableResult
    func deleteAccount() async -> DeleteAccountResult {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let user else {
            return .failed
        }

        do {
            try await user.delete()
            return .success
        }
        catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain,
               nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                signOut()
                errorMessage = String(localized: .authErrorRequiresRecentLogin)
                return .requiresRecentLogin
            }
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            fatalError("Unable to generate nonce: \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        HashUtil.sha256(input)
    }

    /// Maps a Firebase Auth or system NSError into a localized, user-facing message.
    ///
    /// Deliberately says nothing about which provider an address is registered
    /// with. Firebase removed the lookup that made that possible, because
    /// answering it is email enumeration — it tells anyone who asks whether an
    /// address has an account and how it signs in.
    private func localizedAuthError(
        from error: Error,
        attemptedEmail: String?,
    ) async -> String {
        let nsError = error as NSError

        if let authError = error as? AuthError {
            return authError.errorDescription ?? String(localized: .authErrorUnknown)
        }

        guard nsError.domain == AuthErrorDomain else {
            if nsError.domain == NSURLErrorDomain {
                return String(localized: .authErrorNetworkError)
            }
            return String(localized: .authErrorUnknown)
        }

        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return String(localized: .authErrorUnknown)
        }

        switch code {
        case .invalidEmail:
            return String(localized: .authErrorInvalidEmail)
        case .userNotFound:
            return String(localized: .authErrorUserNotFound)
        case .wrongPassword:
            return String(localized: .authErrorWrongPassword)
        case .invalidCredential:
            return String(localized: .authErrorInvalidCredentials)
        case .emailAlreadyInUse:
            return String(localized: .authErrorEmailAlreadyInUse)
        case .accountExistsWithDifferentCredential:
            return String(localized: .authErrorInvalidCredentials)
        case .weakPassword:
            return String(localized: .authErrorWeakPassword)
        case .networkError:
            return String(localized: .authErrorNetworkError)
        case .tooManyRequests:
            return String(localized: .authErrorTooManyRequests)
        case .userDisabled:
            return String(localized: .authErrorUnknown)
        default:
            return String(localized: .authErrorUnknown)
        }
    }

}

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, Sendable {
    private let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization,
    ) {
        continuation.resume(returning: authorization)
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error,
    ) {
        continuation.resume(throwing: error)
    }
}
