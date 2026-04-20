import SwiftUI

struct DraftEditorScreen: View {
    private let navigationTitle: LocalizedStringResource
    private let saveTitle: LocalizedStringResource
    private let titleLimit: Int
    private let descriptionLimit: Int
    private let onSave: (_ title: String, _ description: String, _ link: String, _ topics: Set<Topic>) -> Void

    @Environment(\.dismiss) private var dismiss

    private var title: Binding<String>
    private var description: Binding<String>
    private var link: Binding<String>
    private var selectedTopics: Binding<Set<Topic>>

    init(
        navigationTitle: LocalizedStringResource,
        saveTitle: LocalizedStringResource,
        title: Binding<String>,
        description: Binding<String>,
        link: Binding<String>,
        selectedTopics: Binding<Set<Topic>>,
        titleLimit: Int = 100,
        descriptionLimit: Int = 1000,
        onSave: @escaping (_ title: String, _ description: String, _ link: String, _ topics: Set<Topic>) -> Void
    ) {
        self.navigationTitle = navigationTitle
        self.saveTitle = saveTitle
        self.titleLimit = titleLimit
        self.descriptionLimit = descriptionLimit
        self.onSave = onSave
        self.title = title
        self.description = description
        self.link = link
        self.selectedTopics = selectedTopics
    }

    private var isValid: Bool {
        let hasTitle = !title.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLink = !link.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDescription = !description.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasTitle && !selectedTopics.wrappedValue.isEmpty && (hasLink || hasDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LimitedTextField(
                        text: title,
                        limit: titleLimit,
                        prompt: .saveTitlePlaceholder)
                    TextField(.saveLinkPlaceholder, text: link)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text(.saveDetails)
                }
                Section {
                    LimitedTextEditor(
                        text: description,
                        limit: descriptionLimit)
                } header: {
                    Text(.saveDescription)
                }
                Section {
                    ForEach(Topic.allCases) { topic in
                        Button(action: { toggleTopic(topic) }) {
                            HStack {
                                Label {
                                    Text(topic.title)
                                } icon: {
                                    Image(systemName: topic.symbolName)
                                }
                                Spacer()
                                if selectedTopics.wrappedValue.contains(topic) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(.saveTopic)
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
        if selectedTopics.wrappedValue.contains(topic) {
            selectedTopics.wrappedValue.remove(topic)
        }
        else {
            selectedTopics.wrappedValue.insert(topic)
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        onSave(
            title.wrappedValue,
            description.wrappedValue,
            link.wrappedValue,
            selectedTopics.wrappedValue)
        dismiss()
    }
}

