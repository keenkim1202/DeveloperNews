import BackgroundTasks
import Foundation

/// Keeps the daily digest's text current using iOS background refresh.
///
/// An enhancement, never a dependency: the digest is armed when the setting goes
/// on and again on every foreground refresh, so it fires on time whether or not
/// iOS grants a background run. A granted run only buys a fresher headline.
@MainActor
enum DailyDigestRefresher {
    static let taskIdentifier = "keen-onit.DeveloperNews.dailyDigestRefresh"

    /// Registration has to happen before the app finishes launching, or
    /// `BGTaskScheduler` traps.
    static func register(appState: @escaping @MainActor () -> AppState?) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await handle(task, appState: appState())
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        // A floor, not a promise. iOS decides when, and whether, this runs.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(
        _ task: BGTask,
        appState: AppState?,
    ) async {
        // Re-submitted first: an early return below would otherwise end the
        // chain of refreshes for good.
        schedule()

        guard let appState, appState.notificationsEnabled else {
            task.setTaskCompleted(success: true)
            return
        }

        let work = Task { @MainActor in
            await appState.reload(notifyOnFailure: false)
            await appState.refreshDailyDigest()
        }
        task.expirationHandler = {
            work.cancel()
        }
        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }
}
