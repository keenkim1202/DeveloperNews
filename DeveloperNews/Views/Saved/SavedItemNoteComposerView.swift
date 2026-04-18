import SwiftUI

struct SavedItemNoteComposerView: View {
    let appState: AppState
    let item: ContentItem
    @Environment(\.dismiss) private var dismiss

    @State private var description: String

    init(appState: AppState, item: ContentItem) {
        self.appState = appState
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
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button(action: copyLink) {
                            Label("Copy link", systemImage: "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("save.description")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LimitedTextEditor(text: $description, limit: 2000)
                    }
                }
                .padding(20)
            }
            .navigationTitle("saved.editNote")
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
        guard let saved = appState.savedItemSnapshots[item.url] else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = ContentItem(
            id: saved.id,
            kind: saved.kind,
            title: saved.title,
            summary: trimmed,
            sourceName: saved.sourceName,
            sourceCategory: saved.sourceCategory,
            authorName: saved.authorName,
            url: saved.url,
            publishedAt: saved.publishedAt,
            topics: saved.topics,
            trendScore: saved.trendScore,
            thumbnailURL: saved.thumbnailURL,
            engagement: saved.engagement,
            isUserCreated: saved.isUserCreated,
            updatedAt: .now)
        appState.updateSavedItem(updated)
    }
}

