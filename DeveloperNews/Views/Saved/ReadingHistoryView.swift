import SwiftUI

/// The articles the reader has opened, newest first.
///
/// A history entry is not a bookmark: it records that something was read, which
/// is what makes "that article I saw yesterday" findable without having had the
/// foresight to save it.
struct ReadingHistoryView: View {
    private let appState: AppState

    @State private var showClearConfirm = false

    init(appState: AppState) {
        self.appState = appState
    }

    private var records: [ReadRecord] {
        appState.readHistory
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView {
                    Label(.historyEmpty, icon: .emptyTray)
                } description: {
                    Text(.historyEmptyDescription)
                }
            }
            else {
                list
            }
        }
        .navigationTitle(.historyTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: confirmClear) {
                        Image(.delete)
                    }
                    .accessibilityLabel(Text(.historyClear))
                }
            }
        }
        .alert(.historyClearConfirm, isPresented: $showClearConfirm) {
            Button(.historyClear, role: .destructive, action: clear)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(records) { record in
                    NavigationLink(value: SavedTabDestination.articleDetail(record.url)) {
                        row(for: record)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private func row(for record: ReadRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.title)
                .font(.dsCardTitle)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Text(record.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(relativeDateFormatter.localizedString(for: record.readAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func confirmClear() {
        showClearConfirm = true
    }

    private func clear() {
        appState.clearReadHistory()
    }
}
