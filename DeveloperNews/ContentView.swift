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
        .onAppear(perform: onAppear)
    }

    private func onAppear() {
        if let user = appState.authService.user {
            appState.profileService.startListening(for: user)
        }
        appState.communityService.startListening()
        appState.startListeningForActivities()
        appState.processPendingSharedItems()
    }

    private func loadContent() async {
        await appState.loadIfNeeded()
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
        appState.processPendingSharedItems()
        Task {
            await appState.refreshIfStale(maxAge: AppState.feedStaleThreshold)
            await appState.refreshDailyDigest()
        }
    }

    private func onIsSignedInChange(_ signedIn: Bool) {
        if signedIn, let user = appState.authService.user {
            appState.profileService.startListening(for: user)
            appState.startListeningForActivities()
            Task {
                await appState.profileService.createProfileIfNeeded(for: user)
            }
        }
        else {
            appState.profileService.stopListening()
            appState.stopListeningForActivities()
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
            notificationScheduler: NotificationScheduler()))
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

