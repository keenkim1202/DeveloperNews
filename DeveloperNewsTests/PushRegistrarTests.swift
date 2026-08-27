import Foundation
import Testing
@testable import DeveloperNews

// The token and the reader arrive from different places and in either order,
// which is the whole difficulty: a row written too early addresses nobody, and
// one left behind sends a reader's alerts to a phone they signed out of.
@MainActor
@Suite struct PushRegistrarTests {
    @Test func nothingIsWrittenUntilBothHalvesAreKnown() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)
        await registrar.setEnabled(true)

        await registrar.tokenChanged(to: "token-1")
        #expect(store.saved.isEmpty)

        await registrar.userChanged(to: "me")

        #expect(store.saved.map(\.token) == ["token-1"])
        #expect(store.saved.map(\.userId) == ["me"])
    }

    @Test func theOtherOrderWritesTheSameRow() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)
        await registrar.setEnabled(true)

        await registrar.userChanged(to: "me")
        #expect(store.saved.isEmpty)

        await registrar.tokenChanged(to: "token-1")

        #expect(store.saved.map(\.token) == ["token-1"])
    }

    // Signing out has to take the pairing with it. Left in place, the next
    // notification for that account arrives on a phone someone else may hold.
    @Test func signingOutRemovesThePairing() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)
        await registrar.setEnabled(true)
        await registrar.tokenChanged(to: "token-1")
        await registrar.userChanged(to: "me")

        await registrar.userChanged(to: nil)

        #expect(store.removed.map(\.token) == ["token-1"])
        #expect(store.removed.map(\.userId) == ["me"])
    }

    @Test func signingInAsSomeoneElseMovesThePairing() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)
        await registrar.setEnabled(true)
        await registrar.tokenChanged(to: "token-1")
        await registrar.userChanged(to: "me")

        await registrar.userChanged(to: "you")

        #expect(store.removed.map(\.userId) == ["me"])
        #expect(store.saved.map(\.userId) == ["me", "you"])
    }

    // FCM rotates a token on its own schedule. The old row has to go, or the
    // sender keeps addressing a token this device no longer answers to.
    @Test func aRotatedTokenReplacesTheOldRow() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)
        await registrar.setEnabled(true)
        await registrar.userChanged(to: "me")
        await registrar.tokenChanged(to: "token-1")

        await registrar.tokenChanged(to: "token-2")

        #expect(store.removed.map(\.token) == ["token-1"])
        #expect(store.saved.map(\.token) == ["token-1", "token-2"])
    }

    @Test func repeatingWhatIsAlreadyKnownWritesNothingNew() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)
        await registrar.setEnabled(true)
        await registrar.userChanged(to: "me")
        await registrar.tokenChanged(to: "token-1")

        await registrar.userChanged(to: "me")
        await registrar.tokenChanged(to: "token-1")

        #expect(store.saved.count == 1)
        #expect(store.removed.isEmpty)
    }

    // The switch being off has to mean nothing reaches the device. iOS keeps
    // its permission either way, so this flag is the only thing standing
    // between a disabled switch and an alert arriving anyway.
    @Test func nothingIsWrittenWhileAlertsAreOff() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)

        await registrar.userChanged(to: "me")
        await registrar.tokenChanged(to: "token-1")

        #expect(store.saved.isEmpty)

        await registrar.setEnabled(true)
        #expect(store.saved.map(\.token) == ["token-1"])
    }

    @Test func turningAlertsOffTakesTheDeviceOffTheList() async {
        let store = MockPushTokenStoring()
        let registrar = PushRegistrar(store: store)
        await registrar.setEnabled(true)
        await registrar.userChanged(to: "me")
        await registrar.tokenChanged(to: "token-1")

        await registrar.setEnabled(false)

        #expect(store.removed.map(\.token) == ["token-1"])
    }

    // The switch survives a launch and the registrar does not. A reader who
    // turned alerts on last week never opens Settings again, and the token
    // arriving at launch is the only one there will be.
    @Test func launchingWithAlertsOnPairsTheToken() async {
        let store = MockPushTokenStoring()
        let state = VMFixtures.makeAppState(pushRegistrar: PushRegistrar(store: store))
        state.notificationsEnabled = true

        await state.registerForPush(userId: "me")
        await state.pushRegistrar.tokenChanged(to: "token-1")

        #expect(store.saved.map(\.token) == ["token-1"])
    }

    // Signing out runs the same call with no user. Restoring the switch there
    // must not write the row back for the account being left.
    @Test func signingOutWithAlertsOnLeavesNothingPaired() async {
        let store = MockPushTokenStoring()
        let state = VMFixtures.makeAppState(pushRegistrar: PushRegistrar(store: store))
        state.notificationsEnabled = true
        await state.registerForPush(userId: "me")
        await state.pushRegistrar.tokenChanged(to: "token-1")

        await state.registerForPush(userId: nil)

        #expect(store.removed.map(\.userId) == ["me"])
        #expect(store.saved.map(\.userId) == ["me"])
    }
}
