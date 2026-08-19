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
            Group {
                switch state {
                case .idle, .loading:
                    loading
                case let .ready(lines):
                    summary(lines)
                case let .failed(error):
                    failure(for: error)
                }
            }
            .navigationTitle(.summaryTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
            Text(error == .notEnoughText ? .summaryNotEnoughText : .summaryFailed)
        } actions: {
            if error != .notEnoughText {
                Button(action: onRetry) {
                    Text(.summaryRetry)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
