//
//  DeveloperNewsApp.swift
//  DeveloperNews
//
//  Created by KEEN on 4/11/26.
//

import Foundation
import SwiftUI

@main
struct DeveloperNewsApp: App {
    init() {
        configureSharedImageCache()
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
}
