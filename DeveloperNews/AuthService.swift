import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn

@Observable
final class AuthService {
    private(set) var user: FirebaseAuth.User?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isSignedIn: Bool { user != nil }
    var userId: String? { user?.uid }

    var displayName: String? { user?.displayName }
    var email: String? { user?.email }
    var photoURL: URL? { user?.photoURL }

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
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
        defer { isLoading = false }

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
                fullName: appleIDCredential.fullName
            )

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
                errorMessage = error.localizedDescription
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
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            return authResult.additionalUserInfo?.isNewUser ?? false
        }
        catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                // User canceled — not an error
            }
            else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Email / Password

    @discardableResult
    func signInWithEmail(_ email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            return false
        }
        catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func signUpWithEmail(_ email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
            return true
        }
        catch {
            errorMessage = error.localizedDescription
            return false
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
                errorMessage = String(localized: "auth.error.requiresRecentLogin")
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
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        HashUtil.sha256(input)
    }
}

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, Sendable {
    private let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

enum AuthError: LocalizedError {
    case invalidCredential
    case missingClientID
    case missingRootViewController

    var errorDescription: String? {
        switch self {
        case .invalidCredential: String(localized: "auth.error.invalidCredential")
        case .missingClientID: String(localized: "auth.error.missingClientID")
        case .missingRootViewController: String(localized: "auth.error.missingRootViewController")
        }
    }
}

enum DeleteAccountResult {
    case success
    case requiresRecentLogin
    case failed
}
