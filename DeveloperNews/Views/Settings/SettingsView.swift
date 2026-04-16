import SwiftUI

struct SettingsView: View {
    let appState: AppState
    @State private var viewModel: SettingsViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: SettingsViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                settingsList
                    .onChange(of: viewModel.scrollToTopTrigger) { _, _ in
                        withAnimation {
                            proxy.scrollTo("__settings_top__", anchor: .top)
                        }
                    }
            }
            .sheet(isPresented: $viewModel.showSignIn) {
                SignInView(appState: appState)
            }
            .alert("profile.editName", isPresented: $viewModel.showEditName) {
                TextField("profile.namePlaceholder", text: $viewModel.editingName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let trimmed = viewModel.editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        await viewModel.updateDisplayName(trimmed)
                    }
                }
            } message: {
                Text("profile.editNameMessage")
            }
            .alert("profile.editEmoji", isPresented: $viewModel.showEmojiPicker) {
                TextField("profile.emojiPlaceholder", text: $viewModel.editingEmoji)
                    .onChange(of: viewModel.editingEmoji) { _, new in
                        let emojis = new.filter(\.isEmoji)
                        if let last = emojis.last {
                            viewModel.editingEmoji = String(last)
                        }
                        else {
                            viewModel.editingEmoji = ""
                        }
                    }
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    guard !viewModel.editingEmoji.isEmpty else { return }
                    Task {
                        await viewModel.updateProfileEmoji(viewModel.editingEmoji)
                    }
                }
            } message: {
                Text("profile.editEmojiMessage")
            }
            .sheet(isPresented: $viewModel.showFeedback) {
                FeedbackView()
                    .presentationDetents([.large])
            }
            .confirmationDialog(
                "auth.deleteAccount.confirmTitle",
                isPresented: $viewModel.showDeleteAccountConfirm,
                titleVisibility: .visible) {
                Button("auth.deleteAccount.confirmAction", role: .destructive) {
                    Task {
                        await viewModel.deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("auth.deleteAccount.confirmMessage")
            }
        }
    }

    private var settingsList: some View {
        List {
            accountSection
                .id("__settings_top__")

            Section("Your topics") {
                Text("\(viewModel.selectedTopics.count) of \(AppState.maxSelectedTopics) selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(Topic.allCases) { topic in
                    let isSelected = viewModel.selectedTopics.contains(topic)
                    let isDisabled = !isSelected && !viewModel.canSelectMoreTopics()

                    Button {
                        viewModel.toggleTopic(topic)
                    } label: {
                        HStack {
                            Label {
                                Text(topic.title)
                            } icon: {
                                Image(systemName: topic.symbolName)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .opacity(isDisabled ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                }
            }

            Section {
                ForEach(SourceCategory.allCases) { category in
                    Toggle(isOn: Binding(
                        get: { viewModel.isSourceCategoryEnabled(category) },
                        set: { viewModel.setSourceCategory(category, enabled: $0) }
                    )) {
                        Label {
                            Text(category.title)
                        } icon: {
                            Image(systemName: category.symbolName)
                        }
                    }
                }
            } header: {
                Text("Sources")
            } footer: {
                Text("Turn off a source to hide it from the home feed.")
            }

            Section {
                Toggle("Daily trending alerts", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                ))

                Text("Push delivery is coming soon. Your choice is saved on this device for now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Notifications")
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Language", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker(selection: Binding(
                    get: { viewModel.translationLanguageCode ?? "" },
                    set: { viewModel.setTranslationLanguage($0.isEmpty ? nil : $0) }
                )) {
                    Text("settings.translationOff").tag("")
                    ForEach(translationLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                } label: {
                    Label("settings.translation", systemImage: "translate")
                }

                Button("Reset topic selection", role: .destructive) {
                    viewModel.resetTopics()
                }

                NavigationLink {
                    BlockedUsersView(appState: appState)
                } label: {
                    HStack {
                        Label("settings.blockedUsers", systemImage: "person.slash")
                        Spacer()
                        if !viewModel.blockedUserIds.isEmpty {
                            Text("\(viewModel.blockedUserIds.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("App")
            }

            Section {
                NavigationLink {
                    SourcesAttributionView()
                } label: {
                    Label("Content sources", systemImage: "doc.text")
                }

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("Privacy policy", systemImage: "hand.raised")
                }

                NavigationLink {
                    TermsOfUseView()
                } label: {
                    Label("Terms of use", systemImage: "doc.plaintext")
                }

                Button {
                    viewModel.showFeedback = true
                } label: {
                    Label("Send feedback", systemImage: "envelope")
                }

                LabeledContent("Version", value: appVersionString)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var accountSection: some View {
        if viewModel.isSignedIn {
            Section {
                NavigationLink {
                    UserProfileView(
                        appState: appState,
                        authorId: viewModel.userId ?? "",
                        authorName: viewModel.displayName,
                        authorEmoji: viewModel.profileEmoji)
                } label: {
                    HStack(spacing: 12) {
                        if let emoji = viewModel.profileEmoji {
                            Text(emoji)
                                .font(.system(size: 36))
                        }
                        else {
                            Image(systemName: "questionmark.circle.dashed")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.displayName.isEmpty ? String(localized: "auth.anonymousUser") : viewModel.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let email = viewModel.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                Button {
                    viewModel.editingEmoji = ""
                    viewModel.showEmojiPicker = true
                } label: {
                    Label("profile.changeEmoji", systemImage: "face.smiling")
                }

                Button {
                    viewModel.editingName = viewModel.displayName
                    viewModel.showEditName = true
                } label: {
                    Label("profile.changeName", systemImage: "pencil")
                }

                Button("auth.signOut", role: .destructive) {
                    viewModel.signOut()
                }

                Button("auth.deleteAccount", role: .destructive) {
                    viewModel.showDeleteAccountConfirm = true
                }
            } header: {
                Text("auth.account")
            }
        }
        else {
            Section {
                Button {
                    viewModel.showSignIn = true
                } label: {
                    HStack {
                        Label("auth.signIn", systemImage: "person.crop.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("auth.account")
            } footer: {
                Text("auth.signInFooter")
            }
        }
    }
}
