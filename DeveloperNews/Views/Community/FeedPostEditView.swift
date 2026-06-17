import SwiftUI

struct FeedPostEditView: View {
    private let originalComment: String
    private let onSave: (String) -> Void

    @State private var text: String
    @FocusState private var fieldFocused: Bool

    @Environment(\.dismiss) private var dismiss

    init(
        originalComment: String,
        onSave: @escaping (String) -> Void,
    ) {
        self.originalComment = originalComment
        self.onSave = onSave
        _text = State(initialValue: originalComment)
    }

    private var canSave: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != originalComment
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($fieldFocused)
                .padding(16)
                .navigationTitle(.communityEditPost)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear(perform: focusField)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(
                            "Cancel",
                            role: .cancel,
                            action: cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(.feedPostSave, action: save)
                            .disabled(!canSave)
                    }
                }
        }
    }

    private func focusField() {
        fieldFocused = true
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}
