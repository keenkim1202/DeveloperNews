import SwiftUI

/// The article's summary, shown as a half-height sheet rather than a full
/// screen — it is something to glance at before deciding to read, not a place
/// to stay.
struct ArticleSummarySheet: View {
    private let state: ArticleDetailViewModel.SummaryState
    private let onRetry: () -> Void

    init(
        state: ArticleDetailViewModel.SummaryState,
        onRetry: @escaping () -> Void,
    ) {
        self.state = state
        self.onRetry = onRetry
    }

    var body: some View {
        NavigationStack {
            ArticleSummaryContent(state: state, onRetry: onRetry)
                .navigationTitle(.summaryTitle)
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// The sheet's contents, separated from the sheet itself so it can be rendered
/// on its own — `ImageRenderer` cannot draw a `NavigationStack` or the
/// presentation modifiers wrapped around it.
struct ArticleSummaryContent: View {
    private let state: ArticleDetailViewModel.SummaryState
    private let onRetry: () -> Void

    init(
        state: ArticleDetailViewModel.SummaryState,
        onRetry: @escaping () -> Void,
    ) {
        self.state = state
        self.onRetry = onRetry
    }

    var body: some View {
        switch state {
        case .idle, .loading:
            loading
        case let .ready(lines):
            summary(lines)
        case let .failed(error):
            failure(for: error)
        }
    }

    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(.summaryLoading)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summary(_ lines: [String]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(.sparkles)
                            .font(.caption2)
                            .foregroundStyle(DSColor.accent)
                        Text(line)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                Text(.summaryOnDeviceNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func failure(for error: ArticleSummaryError) -> some View {
        ContentUnavailableView {
            Label(.summaryTitle, icon: .sparkles)
        } description: {
            Text(Self.message(for: error))
        } actions: {
            switch error {
            case .appleIntelligenceOff:
                // The one case the reader can fix, so it gets a way to fix it.
                Button(action: openSystemSettings) {
                    Text(.summaryOpenSettings)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            case .modelNotReady, .failed:
                Button(action: onRetry) {
                    Text(.summaryRetry)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            case .notEnoughText, .unavailable:
                // Nothing to retry and nothing to change.
                EmptyView()
            }
        }
    }

    private static func message(for error: ArticleSummaryError) -> LocalizedStringResource {
        switch error {
        case .notEnoughText:
            .summaryNotEnoughText
        case .appleIntelligenceOff:
            .summaryAppleIntelligenceOff
        case .modelNotReady:
            .summaryModelNotReady
        case .unavailable:
            .summaryDeviceNotEligible
        case .failed:
            .summaryFailed
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
