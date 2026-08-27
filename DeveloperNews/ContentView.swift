import SwiftUI

@MainActor
struct ContentView: View {
    private let appState: AppState

    @State private var navigation = Navigation()
    @State private var showSplash = true
    @State private var isToastVisible = false
    @State private var toastDismissTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView(appState: appState) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
            }
            else if appState.isOnboardingComplete {
                MainTabView(appState: appState, navigation: navigation)
                    .task(loadContent)
            }
            else {
                TopicSelectionView(appState: appState)
            }
        }
        .overlay(alignment: .top) {
            if isToastVisible, let message = appState.toastMessage {
                ToastView(message: message)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .keenOnChange(of: appState.toastTrigger, perform: onToastTriggerChange)
        .keenOnChange(of: scenePhase, perform: onScenePhaseChange)
        .keenOnChange(of: appState.authService.isSignedIn, perform: onIsSignedInChange)
        .keenOnChange(of: appState.pendingActivityDestination, perform: onPendingActivityDestinationChange)
        .onOpenURL(perform: openDeepLink)
        .onAppear(perform: onAppear)
    }

    /// Opens a widget tap in the reader. The story came from the feed the app
    /// itself published, so `resolveItem` finds it; a link that no longer
    /// resolves lands on the existing unavailable-destination screen.
    private func openDeepLink(_ url: URL) {
        guard let articleURL = DeepLink.articleURL(from: url) else {
            return
        }
        appState.currentTab = .home
        navigation.home = [.articleDetail(articleURL)]
    }

    /// Opens what a tapped push pointed at. Same shape as the widget's deep
    /// link, one tab over.
    private func onPendingActivityDestinationChange() {
        guard let destination = appState.pendingActivityDestination else {
            return
        }
        appState.pendingActivityDestination = nil
        appState.currentTab = .community
        navigation.community = [destination]
    }

    private func onAppear() {
        // A tap that launched the app sets the destination before this view
        // exists, and onChange takes a populated value as its baseline.
        onPendingActivityDestinationChange()
        if let user = appState.authService.user {
            appState.profileService.startListening(for: user)
        }
        // A session restored before this view existed never crosses the
        // signed-in change handler, which is the ordinary launch.
        Task {
            await appState.registerForPush(userId: appState.authService.userId)
        }
        appState.communityService.startListening()
        appState.startListeningForActivities()
        Task {
            await appState.processPendingSharedItems()
        }
    }

    private func loadContent() async {
        await appState.loadIfNeeded()
        appState.refreshWidgetSnapshot()
        await appState.refreshDailyDigest()
        DailyDigestRefresher.schedule()
    }

    private func onToastTriggerChange() {
        guard appState.toastMessage != nil else { return }
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isToastVisible = true
        }
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                isToastVisible = false
            }
        }
    }

    private func onScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active, appState.isOnboardingComplete else {
            return
        }
        Task {
            await appState.processPendingSharedItems()
            await appState.refreshIfStale(maxAge: AppState.feedStaleThreshold)
            appState.refreshWidgetSnapshot()
            await appState.refreshDailyDigest()
        }
    }

    private func onIsSignedInChange(_ signedIn: Bool) {
        if signedIn, let user = appState.authService.user {
            appState.profileService.startListening(for: user)
            appState.startListeningForActivities()
            Task {
                await appState.profileService.createProfileIfNeeded(for: user)
                await appState.registerForPush(userId: appState.authService.userId)
            }
        }
        else {
            appState.profileService.stopListening()
            appState.stopListeningForActivities()
            Task {
                await appState.registerForPush(userId: nil)
            }
        }
    }
}


#Preview {
    ContentView(
        appState: AppState(
            translator: ContentTranslator(),
            authService: AuthService(),
            profileService: ProfileService(),
            communityService: CommunityService(),
            feedPostService: FeedPostService(),
            storyEngagementService: StoryEngagementService(),
            activityService: ActivityService(),
            notificationScheduler: NotificationScheduler(),
            articleSummarizer: ArticleSummarizer()))
}


struct MainTabView: View {
    private let appState: AppState
    private let navigation: Navigation

    @State private var homeViewModel: HomeViewModel
    @State private var community2ViewModel: Community2ViewModel
    @State private var savedViewModel: SavedViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(
        appState: AppState,
        navigation: Navigation,
    ) {
        self.appState = appState
        self.navigation = navigation
        _homeViewModel = State(initialValue: HomeViewModel(appState: appState))
        _community2ViewModel = State(initialValue: Community2ViewModel(appState: appState))
        _savedViewModel = State(initialValue: SavedViewModel(appState: appState))
        _settingsViewModel = State(initialValue: SettingsViewModel(appState: appState))
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { appState.currentTab },
            set: { newValue in
                appState.notifyTabSelected(newValue)
            })
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(
                appState: appState,
                viewModel: homeViewModel,
                navigation: navigation)
                .tabItem {
                    Label(.home, systemImage: "newspaper")
                }
                .tag(AppTab.home)

            Community2View(
                appState: appState,
                viewModel: community2ViewModel,
                navigation: navigation)
                .tabItem {
                    Label(.community, systemImage: "person.2")
                }
                .badge(appState.unreadActivityCount)
                .tag(AppTab.community)

            SavedView(
                appState: appState,
                viewModel: savedViewModel,
                navigation: navigation)
                .tabItem {
                    Label(.bookmarks, systemImage: "bookmark")
                }
                .tag(AppTab.saved)

            SettingsView(
                appState: appState,
                viewModel: settingsViewModel,
                navigation: navigation)
                .tabItem {
                    Label(.settings, systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}
