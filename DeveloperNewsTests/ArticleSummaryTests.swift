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

    @Test func theEntryPointFollowsWhetherTheModelCanRunHere() {
        let summarizer = MockArticleSummarizing()
        summarizer.isAvailable = false

        #expect(!makeViewModel(summarizer: summarizer).isSummaryAvailable)
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
