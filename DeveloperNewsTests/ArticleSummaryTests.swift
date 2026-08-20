import Foundation
import Testing
@testable import DeveloperNews

@MainActor
@Suite struct ArticleSummaryTests {
    private func makeViewModel(
        summarizer: MockArticleSummarizing = MockArticleSummarizing(),
    ) -> ArticleDetailViewModel {
        let state = VMFixtures.makeAppState(summarizer: summarizer)
        return ArticleDetailViewModel(appState: state, item: VMFixtures.makeItem(title: "A story"))
    }

    @Test func summarizingMovesFromIdleToReady() async {
        let summarizer = MockArticleSummarizing()
        summarizer.result = .success(["One", "Two"])
        let viewModel = makeViewModel(summarizer: summarizer)
        #expect(viewModel.summaryState == .idle)

        await viewModel.summarize(paragraphs: ["body"])

        #expect(viewModel.summaryState == .ready(["One", "Two"]))
        #expect(summarizer.requests.first?.title == "A story")
    }

    // Reopening the sheet should show what was already written rather than
    // running the model a second time.
    @Test func aFinishedSummaryIsNotRecomputed() async {
        let summarizer = MockArticleSummarizing()
        let viewModel = makeViewModel(summarizer: summarizer)
        await viewModel.summarize(paragraphs: ["body"])

        await viewModel.summarize(paragraphs: ["body"])

        #expect(summarizer.requests.count == 1)
    }

    @Test func retryingClearsTheResultSoTheNextRequestRuns() async {
        let summarizer = MockArticleSummarizing()
        let viewModel = makeViewModel(summarizer: summarizer)
        await viewModel.summarize(paragraphs: ["body"])

        viewModel.resetSummary()
        await viewModel.summarize(paragraphs: ["body"])

        #expect(summarizer.requests.count == 2)
    }

    @Test func aThinPageIsReportedAsSuchRatherThanAsAFailure() async {
        let summarizer = MockArticleSummarizing()
        summarizer.result = .failure(.notEnoughText)
        let viewModel = makeViewModel(summarizer: summarizer)

        await viewModel.summarize(paragraphs: [])

        #expect(viewModel.summaryState == .failed(.notEnoughText))
    }

    // Only hardware that can never run the model hides the button. A switch the
    // reader can flip, or a download still finishing, both keep it — hiding
    // those means someone one tap away never learns the feature exists.
    @Test func onlyIneligibleHardwareHidesTheEntryPoint() {
        let cases: [(SummaryAvailability, Bool)] = [
            (.available, true),
            (.appleIntelligenceOff, true),
            (.modelNotReady, true),
            (.deviceNotEligible, false),
        ]

        for (availability, isVisible) in cases {
            let summarizer = MockArticleSummarizing()
            summarizer.availability = availability
            #expect(makeViewModel(summarizer: summarizer).isSummaryEntryPointVisible == isVisible)
        }
    }

    // Each reason reaches the sheet as itself, because the sheet offers a
    // different way out for each one.
    @Test func eachReasonSurfacesAsItsOwnOutcome() async {
        let cases: [(SummaryAvailability, ArticleSummaryError)] = [
            (.appleIntelligenceOff, .appleIntelligenceOff),
            (.modelNotReady, .modelNotReady),
            (.deviceNotEligible, .unavailable),
        ]

        for (availability, expected) in cases {
            let summarizer = MockArticleSummarizing()
            summarizer.availability = availability
            let viewModel = makeViewModel(summarizer: summarizer)

            await viewModel.summarize(paragraphs: ["body"])

            #expect(viewModel.summaryState == .failed(expected))
            #expect(summarizer.requests.isEmpty)
        }
    }

    // Models drift between plain lines and bulleted ones, so the markers are
    // stripped rather than assumed absent.
    @Test func bulletMarkersAreStrippedFromTheModelOutput() {
        let parsed = ArticleSummarizer.bulletLines(from: """
        - First point
        * Second point
        • Third point

        Fourth point
        """)

        #expect(parsed == ["First point", "Second point", "Third point", "Fourth point"])
    }
}
