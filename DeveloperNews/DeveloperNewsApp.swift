import CoreText
import Foundation
import SwiftUI

@main
struct DeveloperNewsApp: App {
    init() {
        configureSharedImageCache()
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureSharedImageCache() {
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 200 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "imageCache")
    }

    private func registerCustomFonts() {
        let fontFiles = ["PixelifySans"]
        for name in fontFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
