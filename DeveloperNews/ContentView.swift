import SwiftUI

@MainActor
struct ContentView: View {
    @State private var appState = AppState()
    @State private var showSplash = true
    @State private var isToastVisible = false
    @State private var toastDismissTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    private static let staleThreshold: TimeInterval = 15 * 60

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
                MainTabView(appState: appState)
                    .task {
                        await appState.loadIfNeeded()
                    }
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
        .onChange(of: appState.toastTrigger) { _, _ in
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, appState.isOnboardingComplete else {
                return
            }
            appState.processPendingSharedItems()
            Task {
                await appState.refreshIfStale(maxAge: Self.staleThreshold)
            }
        }
        .onChange(of: appState.authService.isSignedIn) { _, signedIn in
            if signedIn, let user = appState.authService.user {
                appState.profileService.startListening(for: user)
                Task {
                    await appState.profileService.createProfileIfNeeded(for: user)
                }
            }
            else {
                appState.profileService.stopListening()
            }
        }
        .onAppear {
            if let user = appState.authService.user {
                appState.profileService.startListening(for: user)
            }
            appState.communityService.startListening()
            appState.processPendingSharedItems()
        }
    }
}


#Preview {
    ContentView()
}


struct MainTabView: View {
    let appState: AppState

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { appState.currentTab },
            set: { newValue in
                appState.notifyTabSelected(newValue)
            })
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(appState: appState)
                .tabItem {
                    Label("Home", systemImage: "newspaper")
                }
                .tag(AppTab.home)

            CommunityView(appState: appState)
                .tabItem {
                    Label("Community", systemImage: "person.2")
                }
                .tag(AppTab.community)

            SavedView(appState: appState)
                .tabItem {
                    Label("Bookmarks", systemImage: "bookmark")
                }
                .tag(AppTab.saved)

            SettingsView(appState: appState)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}

