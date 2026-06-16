import CoreText
import FirebaseCore
import Foundation
import SwiftUI

@main
struct DeveloperNewsApp: App {
    @State private var appState: AppState

    init() {
        FirebaseApp.configure()
        Self.configureSharedImageCache()
        Self.registerCustomFonts()

        let translator = ContentTranslator()
        let authService = AuthService()
        let profileService = ProfileService()
        let communityService = CommunityService()
        _appState = State(
            initialValue: AppState(
                translator: translator,
                authService: authService,
                profileService: profileService,
                communityService: communityService))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
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
