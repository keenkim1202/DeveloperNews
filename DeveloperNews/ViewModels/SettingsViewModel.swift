import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let appState: AppState

    var showSignIn = false
    var showEditName = false
    var showEmojiPicker = false
    var showEditBio = false
    var showFeedback = false
    var showDeleteAccountConfirm = false
    var editingName = ""
    var editingEmoji = ""
    var editingBio = ""

    init(appState: AppState) {
        self.appState = appState
    }

    var isSignedIn: Bool {
        appState.authService.isSignedIn
    }
    var userId: String? {
        appState.authService.userId
    }
    var email: String? {
        appState.authService.email
    }
    var displayName: String {
        appState.profileService.displayName
    }
    var profileEmoji: String? {
        appState.profileService.profileEmoji
    }
    var profileBio: String? {
        appState.profileService.profileBio
    }
    var selectedTopics: Set<Topic> {
        appState.selectedTopics
    }
    var notificationsEnabled: Bool {
        appState.notificationsEnabled
    }
    var notificationsDeniedBySystem: Bool {
        appState.notificationsDeniedBySystem
    }
    var blockedUserIds: Set<String> {
        appState.blockedUserIds
    }
    var scrollToTopTrigger: Int {
        appState.settingsScrollToTopTrigger
    }

    var translationLanguageCode: String? {
        appState.translator.targetLanguageCode
    }

    func toggleTopic(_ topic: Topic) {
        appState.toggleTopic(topic)
    }

    func canSelectMoreTopics() -> Bool {
        appState.canSelectMoreTopics
    }

    func isSourceCategoryEnabled(_ category: SourceCategory) -> Bool {
        appState.isSourceCategoryEnabled(category)
    }

    func setSourceCategory(
        _ category: SourceCategory,
        enabled: Bool,
    ) {
        appState.setSourceCategory(category, enabled: enabled)
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        await appState.setNotificationsEnabled(enabled)
    }

    func syncNotificationAuthorization() async {
        await appState.syncNotificationAuthorization()
    }

    var summaryAvailability: SummaryAvailability {
        appState.articleSummarizer.availability
    }

    /// True only where the reader can act on the status — turning Apple
    /// Intelligence on. Ineligible hardware and a download in progress are
    /// stated and left alone.
    var canActOnSummaryAvailability: Bool {
        summaryAvailability == .appleIntelligenceOff
    }

    func setTranslationLanguage(_ code: String?) {
        appState.setTranslationLanguage(code)
    }

    func resetTopics() {
        appState.resetTopics()
    }

    func signOut() {
        appState.signOut()
    }

    func deleteAccount() async -> DeleteAccountResult {
        await appState.deleteCurrentAccount()
    }

    func updateDisplayName(_ name: String) async {
        await appState.updateDisplayName(name)
    }

    func updateProfileEmoji(_ emoji: String) async {
        await appState.updateProfileEmoji(emoji)
    }

    func updateBio() async {
        let trimmed = editingBio.trimmingCharacters(in: .whitespacesAndNewlines)
        await appState.updateBio(trimmed)
    }

    func unblockUser(_ userId: String) {
        appState.unblockUser(userId)
    }
}
