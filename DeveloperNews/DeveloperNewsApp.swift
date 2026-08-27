import CoreText
import FirebaseCore
import FirebaseMessaging
import Foundation
import SwiftUI
import UIKit

/// Exists for one callback. APNs hands the device token to the application
/// delegate and nowhere else, and FCM cannot mint its own token without it.
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data,
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

@main
struct DeveloperNewsApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate

    @State private var appState: AppState?

    init() {
        guard !Self.isRunningUnitTests else {
            return
        }

        Self.configureFirebaseIfAvailable()
        Self.configureSharedImageCache()
        Self.registerCustomFonts()

        let translator = ContentTranslator()
        let authService = AuthService()
        let profileService = ProfileService()
        let communityService = CommunityService()
        let feedPostService = FeedPostService()
        let storyEngagementService = StoryEngagementService()
        let activityService = ActivityService()
        let notificationScheduler = NotificationScheduler()
        let articleSummarizer = ArticleSummarizer()
        _appState = State(
            initialValue: AppState(
                translator: translator,
                authService: authService,
                profileService: profileService,
                communityService: communityService,
                feedPostService: feedPostService,
                storyEngagementService: storyEngagementService,
                activityService: activityService,
                notificationScheduler: notificationScheduler,
                articleSummarizer: articleSummarizer))

        // Registration must complete before launch finishes, so it happens here
        // rather than in a task or an onAppear.
        let state = _appState.wrappedValue
        DailyDigestRefresher.register { state }
        state?.pushRegistrar.installDelegates()
    }

    var body: some Scene {
        WindowGroup {
            if let appState {
                ContentView(appState: appState)
            }
        }
    }

    // True when the process is hosting an XCTest bundle. The unit-test target
    // uses this app as its TEST_HOST, so the host must launch without standing
    // up the real Firebase-backed services that tests do not need.
    private static var isRunningUnitTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    // Configures Firebase only when a GoogleService-Info.plist is bundled. The
    // plist is not committed (it carries project secrets), so skipping
    // configuration when it is absent keeps the host from crashing at startup
    // while a real build still configures normally.
    private static func configureFirebaseIfAvailable() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path)
        else {
            return
        }
        FirebaseApp.configure(options: options)
    }

    private static func configureSharedImageCache() {
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 200 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "imageCache")
    }

    private static func registerCustomFonts() {
        let fontFiles = ["PixelifySans"]
        for name in fontFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
