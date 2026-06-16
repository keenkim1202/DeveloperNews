import SwiftUI

struct AddSavedItemView: View {
    @State private var viewModel: AddSavedItemViewModel

    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var selectedTopics: Set<Topic> = []

    init(appState: AppState) {
        _viewModel = State(initialValue: AddSavedItemViewModel(appState: appState))
    }

    var body: some View {
        DraftEditorScreen(
            navigationTitle: .saveAddItem,
            saveTitle: "Save",
            title: $title,
            description: $description,
            link: $link,
            selectedTopics: $selectedTopics
        ) { _, _, _, _ in
            saveItem()
        }
    }

    private func saveItem() {
        viewModel.saveItem(
            title: title,
            description: description,
            link: link,
            selectedTopics: selectedTopics)
    }
}

