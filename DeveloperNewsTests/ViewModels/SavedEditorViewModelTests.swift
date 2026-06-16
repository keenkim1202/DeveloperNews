import XCTest
@testable import DeveloperNews

@MainActor
final class SavedEditorViewModelTests: XCTestCase {
    // MARK: - AddSavedItemViewModel

    func testAddSavedItemUsesProvidedLink() async {
        let appState = VMFixtures.makeAppState()
        VMFixtures.resetState(appState)
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "Hello",
            description: "World",
            link: "https://example.com/post",
            selectedTopics: [.ios])

        XCTAssertEqual(appState.savedItems.count, 1)
        let saved = appState.savedItems.first
        XCTAssertEqual(saved?.url.absoluteString, "https://example.com/post")
        XCTAssertEqual(saved?.title, "Hello")
        XCTAssertEqual(saved?.topics, [.ios])
        XCTAssertTrue(saved?.isUserCreated == true)

        await VMFixtures.drainPersistence()
    }

    func testAddSavedItemSynthesizesURLWhenLinkEmpty() async {
        let appState = VMFixtures.makeAppState()
        VMFixtures.resetState(appState)
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "No link",
            description: "x",
            link: "   ",
            selectedTopics: [])

        XCTAssertEqual(appState.savedItems.count, 1)
        let saved = appState.savedItems.first
        XCTAssertEqual(saved?.url.scheme, "devnews")
        XCTAssertFalse(saved?.hasExternalLink == true)

        await VMFixtures.drainPersistence()
    }

    func testAddSavedItemUsesDisplayNameAsSource() async {
        let profile = MockProfileServicing()
        profile.displayName = "Jane Dev"
        let appState = VMFixtures.makeAppState(profile: profile)
        VMFixtures.resetState(appState)
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "T",
            description: "D",
            link: "https://example.com/x",
            selectedTopics: [])

        XCTAssertEqual(appState.savedItems.first?.sourceName, "Jane Dev")

        await VMFixtures.drainPersistence()
    }

    func testAddSavedItemFallsBackToLocalizedSourceWhenNoDisplayName() async {
        let profile = MockProfileServicing()
        profile.displayName = ""
        let appState = VMFixtures.makeAppState(profile: profile)
        VMFixtures.resetState(appState)
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "T",
            description: "D",
            link: "https://example.com/x",
            selectedTopics: [])

        let saved = appState.savedItems.first
        XCTAssertEqual(saved?.sourceName, String(localized: .saveMyBookmark))
        XCTAssertFalse(saved?.sourceName.isEmpty == true)

        await VMFixtures.drainPersistence()
    }

    func testAddSavedItemTrimsTitleAndDescription() async {
        let appState = VMFixtures.makeAppState()
        VMFixtures.resetState(appState)
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "  Trimmed  ",
            description: "  Body  ",
            link: "https://example.com/y",
            selectedTopics: [])

        let saved = appState.savedItems.first
        XCTAssertEqual(saved?.title, "Trimmed")
        XCTAssertEqual(saved?.summary, "Body")

        await VMFixtures.drainPersistence()
    }

    // MARK: - EditBookmarkViewModel

    func testEditUpdatesInPlaceWhenURLUnchanged() async {
        let appState = VMFixtures.makeAppState()
        VMFixtures.resetState(appState)
        let original = VMFixtures.makeItem(
            title: "Old",
            urlString: "https://example.com/keep")
        appState.addSavedItem(original)

        let vm = EditBookmarkViewModel(appState: appState, item: original)
        vm.saveChanges(
            title: "New Title",
            description: "New Body",
            link: original.url.absoluteString,
            selectedTopics: [.web])

        XCTAssertEqual(appState.savedItems.count, 1)
        let saved = appState.savedItems.first
        XCTAssertEqual(saved?.url, original.url)
        XCTAssertEqual(saved?.title, "New Title")
        XCTAssertEqual(saved?.summary, "New Body")
        XCTAssertEqual(saved?.topics, [.web])

        await VMFixtures.drainPersistence()
    }

    func testEditChangingURLRemovesOldAndAddsNew() async {
        let appState = VMFixtures.makeAppState()
        VMFixtures.resetState(appState)
        let original = VMFixtures.makeItem(
            title: "Old",
            urlString: "https://example.com/old")
        appState.addSavedItem(original)

        let vm = EditBookmarkViewModel(appState: appState, item: original)
        vm.saveChanges(
            title: "Moved",
            description: "d",
            link: "https://example.com/new",
            selectedTopics: [])

        XCTAssertEqual(appState.savedItems.count, 1)
        let saved = appState.savedItems.first
        XCTAssertEqual(saved?.url.absoluteString, "https://example.com/new")
        XCTAssertEqual(saved?.title, "Moved")
        XCTAssertNil(appState.savedItems.first { $0.url == original.url })

        await VMFixtures.drainPersistence()
    }

    func testEditClearingLinkOnExternalItemSynthesizesURL() async {
        let appState = VMFixtures.makeAppState()
        VMFixtures.resetState(appState)
        let original = VMFixtures.makeItem(
            title: "Old",
            urlString: "https://example.com/external")
        appState.addSavedItem(original)

        let vm = EditBookmarkViewModel(appState: appState, item: original)
        vm.saveChanges(
            title: "Now Local",
            description: "d",
            link: "",
            selectedTopics: [])

        XCTAssertEqual(appState.savedItems.count, 1)
        let saved = appState.savedItems.first
        XCTAssertEqual(saved?.url.scheme, "devnews")
        XCTAssertTrue(saved?.url.absoluteString.contains(original.id.uuidString) == true)

        await VMFixtures.drainPersistence()
    }
}
