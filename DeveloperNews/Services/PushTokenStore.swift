@preconcurrency import FirebaseFirestore
import Foundation

@MainActor
final class PushTokenStore: PushTokenStoring {
    // Resolved on first use, not on init. The unit-test host builds an
    // `AppState` without configuring Firebase, and asking for the default
    // instance before that throws.
    private lazy var db = Firestore.firestore()

    private func tokensRef(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("pushTokens")
    }

    /// Failures are swallowed on purpose. A token that did not save means a push
    /// that does not arrive, which the next launch retries — surfacing it would
    /// put an error in front of a reader who did nothing and can do nothing.
    func save(_ token: String, userId: String) async {
        try? await tokensRef(userId).document(token).setData([
            "updatedAt": FieldValue.serverTimestamp(),
            "platform": "ios",
        ])
    }

    func remove(_ token: String, userId: String) async {
        try? await tokensRef(userId).document(token).delete()
    }
}
