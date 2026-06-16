import SwiftUI

struct SavedItemNoteComposerView: View {
    @State private var viewModel: SavedItemNoteComposerViewModel
    private let item: ContentItem

    @State private var description: String

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        item: ContentItem,
    ) {
        _viewModel = State(initialValue: SavedItemNoteComposerViewModel(
            appState: appState,
            item: item))
        self.item = item
        _description = State(initialValue: item.summary)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.sourceName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(item.url.absoluteString)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                Color(.secondarySystemBackground)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button(action: copyLink) {
                            Label("Copy link", systemImage: "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(.saveDescription)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LimitedTextEditor(text: $description, limit: 2000)
                    }
                }
                .padding(20)
            }
            .navigationTitle(.savedEditNote)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func copyLink() {
        UIPasteboard.general.string = item.url.absoluteString
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        saveChanges()
        dismiss()
    }

    private func saveChanges() {
        viewModel.saveChanges(description: description)
    }
}

