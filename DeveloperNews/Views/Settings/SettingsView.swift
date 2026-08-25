import SwiftUI

struct SettingsView: View {
    private let appState: AppState

    @Bindable private var viewModel: SettingsViewModel
    @Bindable private var navigation: Navigation
    @State private var signInViewModel: SignInViewModel

    init(
        appState: AppState,
        viewModel: SettingsViewModel,
        navigation: Navigation,
    ) {
        self.appState = appState
        self.viewModel = viewModel
        self.navigation = navigation
        _signInViewModel = State(initialValue: SignInViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack(path: $navigation.settings) {
            ScrollViewReader { proxy in
                settingsList
                    .keenOnChange(of: viewModel.scrollToTopTrigger) {
                        withAnimation {
                            proxy.scrollTo("__settings_top__", anchor: .top)
                        }
                    }
            }
            .navigationDestination(for: SettingsTabDestination.self, destination: destination)
            .task(syncNotificationAuthorization)
            .alert(.profileEditName, isPresented: $viewModel.showEditName) {
                TextField(.profileNamePlaceholder, text: $viewModel.editingName)
                Button(
                    "Cancel",
                    role: .cancel) {}
                Button("Save", action: saveDisplayName)
            } message: {
                Text(.profileEditNameMessage)
            }
            .alert(.profileEditEmoji, isPresented: $viewModel.showEmojiPicker) {
                TextField(.profileEmojiPlaceholder, text: $viewModel.editingEmoji)
                    .keenOnChange(of: viewModel.editingEmoji, perform: onEditingEmojiChange)
                Button(
                    "Cancel",
                    role: .cancel) {}
                Button("Save", action: saveProfileEmoji)
            } message: {
                Text(.profileEditEmojiMessage)
            }
            .dialog(
                "auth.deleteAccount.confirmTitle",
                message: "auth.deleteAccount.confirmMessage",
                isPresented: $viewModel.showDeleteAccountConfirm,
                buttons: deleteAccountConfirmDialogView)
            .sheet(isPresented: $viewModel.showEditBio) {
                bioEditorSheet
            }
            .sheet(isPresented: $viewModel.showSignIn) {
                SignInView(appState: appState, viewModel: signInViewModel)
            }
            .sheet(isPresented: $viewModel.showFeedback) {
                FeedbackView()
                    .presentationDetents([.large])
            }
        }
    }

    private var deleteAccountConfirmDialogView: some View {
        Button(
            "auth.deleteAccount.confirmAction",
            role: .destructive,
            action: deleteAccount)
    }

    private var bioEditorSheet: some View {
        NavigationStack {
            LimitedTextEditor(
                text: $viewModel.editingBio,
                limit: 160,
                placeholder: .profileBioPlaceholder)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle(.profileEditBio)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancelBio)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: saveBio)
                    }
                }
        }
    }

    @ViewBuilder
    private func destination(_ dest: SettingsTabDestination) -> some View {
        switch dest {
        case .blockedUsers:
            BlockedUsersView(appState: appState)
        case .sourcesAttribution:
            SourcesAttributionView()
        case .privacyPolicy:
            PrivacyPolicyView()
        case .termsOfUse:
            TermsOfUseView()
        case let .userProfile(userId):
            UserProfileView(appState: appState, authorId: userId)
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
                    Button(action: { toggleTopic(topic) }) {
                        HStack {
                            Label {
                                Text(topic.title)
                            } icon: {
                                Image(systemName: topic.symbolName)
                            }
                            Spacer()
                            if isSelected {
                                Image(.checkmarkCircleFill)
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
                    set: { setNotificationsEnabled($0) }
                ))
                if viewModel.notificationsDeniedBySystem {
                    Button(action: openSystemSettings) {
                        Label(.notificationOpenSettings, icon: .globe)
                    }
                }
            } header: {
                Text(.notifications)
            } footer: {
                Text(
                    viewModel.notificationsDeniedBySystem
                        ? .notificationPermissionDeniedMessage
                        : .settingsDailyDigestFooter)
            }

            // Says why summaries are or are not available here. Without it, a
            // reader whose device cannot run them has no way to tell the
            // feature apart from a bug.
            Section {
                if viewModel.canActOnSummaryAvailability {
                    Button(action: openSystemSettings) {
                        summaryStatusRow
                    }
                }
                else {
                    summaryStatusRow
                }
            } footer: {
                Text(.settingsSummaryFooter)
            }

            Section {
                Picker(selection: Binding(
                    get: { viewModel.readerTextSize },
                    set: { viewModel.setReaderTextSize($0) }
                )) {
                    ForEach(ReaderTextSize.allCases) { size in
                        Text(Self.label(for: size)).tag(size)
                    }
                } label: {
                    Label(.settingsTextSize, icon: .document)
                }
            } footer: {
                Text(.settingsTextSizeFooter)
            }

            Section {
                Button(action: openSystemSettings) {
                    HStack {
                        Label(.language, icon: .globe)
                        Spacer()
                        Image(.externalLinkSquare)
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
                    Label(.settingsTranslation, icon: .translate)
                }
                Button(
                    .resetTopicSelection,
                    role: .destructive,
                    action: resetTopics)

                NavigationLink(value: SettingsTabDestination.blockedUsers) {
                    HStack {
                        Label(.settingsBlockedUsers, icon: .blockedUsers)
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
                NavigationLink(value: SettingsTabDestination.sourcesAttribution) {
                    Label(.contentSources, icon: .document)
                }
                NavigationLink(value: SettingsTabDestination.privacyPolicy) {
                    Label(.privacyPolicy, icon: .privacy)
                }
                NavigationLink(value: SettingsTabDestination.termsOfUse) {
                    Label(.termsOfUse, icon: .terms)
                }
                Button(action: openFeedback) {
                    Label(.sendFeedback, icon: .feedback)
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
                NavigationLink(
                    value: SettingsTabDestination.userProfile(userId: viewModel.userId ?? "")
                ) {
                    HStack(spacing: 12) {
                        if let emoji = viewModel.profileEmoji {
                            Text(emoji)
                                .font(.system(size: 36))
                        }
                        else {
                            Image(.unknown)
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
                    Label(.profileChangeEmoji, icon: .emoji)
                }
                Button(action: openNameEditor) {
                    Label(.profileChangeName, icon: .edit)
                }
                Button(action: openBioEditor) {
                    if let bio = viewModel.profileBio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    else {
                        Label(.profileAddBio, icon: .edit)
                    }
                }
                Button(
                    .authSignOut,
                    role: .destructive,
                    action: signOut)
                Button(
                    .authDeleteAccount,
                    role: .destructive,
                    action: confirmDeleteAccount)
            } header: {
                Text(.authAccount)
            }
        }
        else {
            Section {
                Button(action: openSignIn) {
                    HStack {
                        Label(.authSignIn, icon: .account)
                        Spacer()
                        Image(.chevronForward)
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

    // Catches permission revoked outside the app, which would otherwise leave
    // a switch that is on and a digest that never arrives.
    private static func label(for size: ReaderTextSize) -> LocalizedStringResource {
        switch size {
        case .small:
            .settingsTextSizeSmall
        case .standard:
            .settingsTextSizeStandard
        case .large:
            .settingsTextSizeLarge
        case .extraLarge:
            .settingsTextSizeExtraLarge
        }
    }

    private func syncNotificationAuthorization() async {
        await viewModel.syncNotificationAuthorization()
    }

    private var summaryStatusRow: some View {
        HStack {
            Label(.settingsSummaryStatus, icon: .sparkles)
            Spacer()
            Text(summaryStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if viewModel.canActOnSummaryAvailability {
                Image(.chevronForward)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var summaryStatusText: LocalizedStringResource {
        switch viewModel.summaryAvailability {
        case .available:
            .settingsSummaryAvailable
        case .appleIntelligenceOff:
            .summaryAppleIntelligenceOff
        case .modelNotReady:
            .summaryModelNotReady
        case .deviceNotEligible:
            .summaryDeviceNotEligible
        }
    }

    private func setNotificationsEnabled(_ enabled: Bool) {
        Task {
            await viewModel.setNotificationsEnabled(enabled)
        }
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

    private func openBioEditor() {
        viewModel.editingBio = viewModel.profileBio ?? ""
        viewModel.showEditBio = true
    }

    private func saveBio() {
        Task {
            await viewModel.updateBio()
        }
        viewModel.showEditBio = false
    }

    private func cancelBio() {
        viewModel.showEditBio = false
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
