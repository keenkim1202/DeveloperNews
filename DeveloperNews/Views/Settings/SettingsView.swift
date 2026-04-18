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
                    .keenOnChange(of: viewModel.scrollToTopTrigger) {
                        withAnimation {
                            proxy.scrollTo("__settings_top__", anchor: .top)
                        }
                    }
            }
            .sheet(isPresented: $viewModel.showSignIn) {
                SignInView(appState: appState)
            }
            .alert(.profileEditName, isPresented: $viewModel.showEditName) {
                TextField(.profileNamePlaceholder, text: $viewModel.editingName)
                Button("Cancel", role: .cancel) {}
                Button("Save", action: saveDisplayName)
            } message: {
                Text(.profileEditNameMessage)
            }
            .alert(.profileEditEmoji, isPresented: $viewModel.showEmojiPicker) {
                TextField(.profileEmojiPlaceholder, text: $viewModel.editingEmoji)
                    .keenOnChange(of: viewModel.editingEmoji, perform: onEditingEmojiChange)
                Button("Cancel", role: .cancel) {}
                Button("Save", action: saveProfileEmoji)
            } message: {
                Text(.profileEditEmojiMessage)
            }
            .sheet(isPresented: $viewModel.showFeedback) {
                FeedbackView()
                    .presentationDetents([.large])
            }
            .confirmationDialog(
                "auth.deleteAccount.confirmTitle",
                isPresented: $viewModel.showDeleteAccountConfirm,
                titleVisibility: .visible) {
                Button("auth.deleteAccount.confirmAction", role: .destructive, action: deleteAccount)
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

            Section(.yourTopics) {
                Text("\(viewModel.selectedTopics.count) of \(AppState.maxSelectedTopics) selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(Topic.allCases) { topic in
                    let isSelected = viewModel.selectedTopics.contains(topic)
                    let isDisabled = !isSelected && !viewModel.canSelectMoreTopics()

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
                Text(.sources)
            } footer: {
                Text(.turnOffASourceToHideItFromTheHomeFeed)
            }

            Section {
                Toggle(.dailyTrendingAlerts, isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                ))

                Text(.pushDeliveryIsComingSoonYourChoiceIsSavedOnThisDeviceForNow)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(.notifications)
            }

            Section {
                Button(action: openSystemSettings) {
                    HStack {
                        Label(.language, systemImage: "globe")
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
                    Text(.settingsTranslationOff).tag("")
                    ForEach(translationLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                } label: {
                    Label(.settingsTranslation, systemImage: "translate")
                }

                Button(.resetTopicSelection, role: .destructive, action: resetTopics)

                NavigationLink {
                    BlockedUsersView(appState: appState)
                } label: {
                    HStack {
                        Label(.settingsBlockedUsers, systemImage: "person.slash")
                        Spacer()
                        if !viewModel.blockedUserIds.isEmpty {
                            Text("\(viewModel.blockedUserIds.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(.app)
            }

            Section {
                NavigationLink {
                    SourcesAttributionView()
                } label: {
                    Label(.contentSources, systemImage: "doc.text")
                }

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label(.privacyPolicy, systemImage: "hand.raised")
                }

                NavigationLink {
                    TermsOfUseView()
                } label: {
                    Label(.termsOfUse, systemImage: "doc.plaintext")
                }

                Button(action: openFeedback) {
                    Label(.sendFeedback, systemImage: "envelope")
                }

                LabeledContent(.version, value: appVersionString)
            } header: {
                Text(.about)
            }
        }
        .navigationTitle(.settings)
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
                            Text(viewModel.displayName.isEmpty ? String(localized: .authAnonymousUser) : viewModel.displayName)
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

                Button(action: openEmojiPicker) {
                    Label(.profileChangeEmoji, systemImage: "face.smiling")
                }

                Button(action: openNameEditor) {
                    Label(.profileChangeName, systemImage: "pencil")
                }

                Button(.authSignOut, role: .destructive, action: signOut)

                Button(.authDeleteAccount, role: .destructive, action: confirmDeleteAccount)
            } header: {
                Text(.authAccount)
            }
        }
        else {
            Section {
                Button(action: openSignIn) {
                    HStack {
                        Label(.authSignIn, systemImage: "person.crop.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(.authAccount)
            } footer: {
                Text(.authSignInFooter)
            }
        }
    }

    private func onEditingEmojiChange(_ new: String) {
        let emojis = new.filter(\.isEmoji)
        if let last = emojis.last {
            viewModel.editingEmoji = String(last)
        }
        else {
            viewModel.editingEmoji = ""
        }
    }

    private func saveDisplayName() {
        let trimmed = viewModel.editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            await viewModel.updateDisplayName(trimmed)
        }
    }

    private func saveProfileEmoji() {
        guard !viewModel.editingEmoji.isEmpty else { return }
        Task {
            await viewModel.updateProfileEmoji(viewModel.editingEmoji)
        }
    }

    private func deleteAccount() {
        Task {
            await viewModel.deleteAccount()
        }
    }

    private func toggleTopic(_ topic: Topic) {
        viewModel.toggleTopic(topic)
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func resetTopics() {
        viewModel.resetTopics()
    }

    private func openFeedback() {
        viewModel.showFeedback = true
    }

    private func openEmojiPicker() {
        viewModel.editingEmoji = ""
        viewModel.showEmojiPicker = true
    }

    private func openNameEditor() {
        viewModel.editingName = viewModel.displayName
        viewModel.showEditName = true
    }

    private func signOut() {
        viewModel.signOut()
    }

    private func confirmDeleteAccount() {
        viewModel.showDeleteAccountConfirm = true
    }

    private func openSignIn() {
        viewModel.showSignIn = true
    }
}
