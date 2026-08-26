import Foundation

/// Where a device's push token lives while the reader is signed in.
///
/// One document per token rather than a field on the user: a person reads on
/// more than one device, and the sender has to reach all of them. The token is
/// also the document id, so re-registering the same device rewrites its row
/// instead of adding another.
@MainActor
protocol PushTokenStoring {
    func save(_ token: String, userId: String) async
    func remove(_ token: String, userId: String) async
}
