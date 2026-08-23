import AppIntents

/// The shortcuts the system offers without the reader building one first —
/// they show up in Spotlight and the Shortcuts app on install.
struct DeveloperNewsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTopStoryIntent(),
            phrases: [
                "Open the top story in \(.applicationName)",
                "What is trending in \(.applicationName)",
                "\(.applicationName) top story",
            ],
            shortTitle: "Top story",
            systemImageName: "sparkles")
    }
}
