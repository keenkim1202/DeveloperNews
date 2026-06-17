import Testing
import Foundation
@testable import DeveloperNews

@MainActor
@Suite struct SavedEditorViewModelTests {
    // MARK: - AddSavedItemViewModel

    @Test func addSavedItemUsesProvidedLink() async {
        let appState = VMFixtures.makeAppState()
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "Hello",
            description: "World",
            link: "https://example.com/post",
            selectedTopics: [.ios])

        #expect(appState.savedItems.count == 1)
        let saved = appState.savedItems.first
        #expect(saved?.url.absoluteString == "https://example.com/post")
        #expect(saved?.title == "Hello")
        #expect(saved?.topics == [.ios])
        #expect(saved?.isUserCreated == true)
    }

    @Test func addSavedItemSynthesizesURLWhenLinkEmpty() async {
        let appState = VMFixtures.makeAppState()
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "No link",
            description: "x",
            link: "   ",
            selectedTopics: [])

        #expect(appState.savedItems.count == 1)
        let saved = appState.savedItems.first
        #expect(saved?.url.scheme == "devnews")
        #expect(!(saved?.hasExternalLink == true))
    }

    @Test func addSavedItemUsesDisplayNameAsSource() async {
        let profile = MockProfileServicing()
        profile.displayName = "Jane Dev"
        let appState = VMFixtures.makeAppState(profile: profile)
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "T",
            description: "D",
            link: "https://example.com/x",
            selectedTopics: [])

        #expect(appState.savedItems.first?.sourceName == "Jane Dev")
    }

    @Test func addSavedItemFallsBackToLocalizedSourceWhenNoDisplayName() async {
        let profile = MockProfileServicing()
        profile.displayName = ""
        let appState = VMFixtures.makeAppState(profile: profile)
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "T",
            description: "D",
            link: "https://example.com/x",
            selectedTopics: [])

        let saved = appState.savedItems.first
        #expect(saved?.sourceName == String(localized: .saveMyBookmark))
        #expect(!(saved?.sourceName.isEmpty == true))
    }

    @Test func addSavedItemTrimsTitleAndDescription() async {
        let appState = VMFixtures.makeAppState()
        let vm = AddSavedItemViewModel(appState: appState)

        vm.saveItem(
            title: "  Trimmed  ",
            description: "  Body  ",
            link: "https://example.com/y",
            selectedTopics: [])

        let saved = appState.savedItems.first
        #expect(saved?.title == "Trimmed")
        #expect(saved?.summary == "Body")
    }

    // MARK: - EditBookmarkViewModel

    @Test func editUpdatesInPlaceWhenURLUnchanged() async {
        let appState = VMFixtures.makeAppState()
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

        #expect(appState.savedItems.count == 1)
        let saved = appState.savedItems.first
        #expect(saved?.url == original.url)
        #expect(saved?.title == "New Title")
        #expect(saved?.summary == "New Body")
        #expect(saved?.topics == [.web])
    }

    @Test func editChangingURLRemovesOldAndAddsNew() async {
        let appState = VMFixtures.makeAppState()
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

        #expect(appState.savedItems.count == 1)
        let saved = appState.savedItems.first
        #expect(saved?.url.absoluteString == "https://example.com/new")
        #expect(saved?.title == "Moved")
        #expect(appState.savedItems.first { $0.url == original.url } == nil)
    }

    @Test func editClearingLinkOnExternalItemSynthesizesURL() async {
        let appState = VMFixtures.makeAppState()
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

        #expect(appState.savedItems.count == 1)
        let saved = appState.savedItems.first
        #expect(saved?.url.scheme == "devnews")
        #expect(saved?.url.absoluteString.contains(original.id.uuidString) == true)
    }
}
