import SwiftUI

struct DraftEditorScreen: View {
    let navigationTitle: LocalizedStringResource
    let saveTitle: LocalizedStringResource
    let titleLimit: Int
    let descriptionLimit: Int
    let onSave: (String, String, String, Set<Topic>) -> Void

    @Environment(\.dismiss) private var dismiss

    @Binding var title: String
    @Binding var description: String
    @Binding var link: String
    @Binding var selectedTopics: Set<Topic>

    init(
        navigationTitle: LocalizedStringResource,
        saveTitle: LocalizedStringResource,
        title: Binding<String>,
        description: Binding<String>,
        link: Binding<String>,
        selectedTopics: Binding<Set<Topic>>,
        titleLimit: Int = 100,
        descriptionLimit: Int = 1000,
        onSave: @escaping (String, String, String, Set<Topic>) -> Void
    ) {
        self.navigationTitle = navigationTitle
        self.saveTitle = saveTitle
        self.titleLimit = titleLimit
        self.descriptionLimit = descriptionLimit
        self.onSave = onSave
        _title = title
        _description = description
        _link = link
        _selectedTopics = selectedTopics
    }

    private var isValid: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLink = !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDescription = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && !selectedTopics.isEmpty && (hasLink || hasDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LimitedTextField(text: $title, limit: titleLimit, prompt: "save.titlePlaceholder")

                    TextField("save.linkPlaceholder", text: $link)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("save.details")
                }

                Section {
                    LimitedTextEditor(text: $description, limit: descriptionLimit)
                } header: {
                    Text("save.description")
                }

                Section {
                    ForEach(Topic.allCases) { topic in
                        Button {
                            toggleTopic(topic)
                        } label: {
                            HStack {
                                Label {
                                    Text(topic.title)
                                } icon: {
                                    Image(systemName: topic.symbolName)
                                }
                                Spacer()
                                if selectedTopics.contains(topic) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("save.topic")
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle, action: save)
                        .disabled(!isValid)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func toggleTopic(_ topic: Topic) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
        }
        else {
            selectedTopics.insert(topic)
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        onSave(title, description, link, selectedTopics)
        dismiss()
    }
}

