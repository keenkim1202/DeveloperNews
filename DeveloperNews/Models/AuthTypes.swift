import Foundation

enum AuthError: LocalizedError {
    case invalidCredential
    case missingClientID
    case missingRootViewController

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            NSLocalizedString("auth.error.invalidCredential", comment: "Invalid sign-in credentials")
        case .missingClientID:
            NSLocalizedString("auth.error.missingClientID", comment: "Missing Google client ID")
        case .missingRootViewController:
            NSLocalizedString("auth.error.missingRootViewController", comment: "Missing sign-in presenter")
        }
    }
}

enum DeleteAccountResult {
    case success
    case requiresRecentLogin
    case failed
}

enum PasswordResetResult {
    case success
    case failed(String)
}
