import Foundation
import Testing
@testable import DeveloperNews

// The translate button is always on screen now, so the case that matters is the
// one where no language has been chosen yet: tapping has to be able to set one.
@MainActor
@Suite struct ArticleDetailViewModelTests {
    private func makeViewModel(
        translator: MockTranslating = MockTranslating(),
    ) -> (ArticleDetailViewModel, AppState) {
        let state = VMFixtures.makeAppState(translator: translator)
        let item = VMFixtures.makeItem(title: "A story")
        return (ArticleDetailViewModel(appState: state, item: item), state)
    }

    @Test func translationIsUnavailableUntilALanguageIsChosen() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.translationLanguageCode == nil)
        #expect(!viewModel.canTranslate)
    }

    @Test func choosingALanguageMakesTranslationAvailable() {
        let (viewModel, _) = makeViewModel()

        viewModel.setTranslationLanguage("ko")

        #expect(viewModel.translationLanguageCode == "ko")
        #expect(viewModel.canTranslate)
    }

    // The picker writes through to the shared setting, so the choice sticks for
    // the next article and shows up in Settings.
    @Test func theChoiceIsSharedWithTheRestOfTheApp() {
        let (viewModel, state) = makeViewModel()

        viewModel.setTranslationLanguage("ja")

        #expect(state.translator.targetLanguageCode == "ja")
    }
}
