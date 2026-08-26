import Foundation
import Testing
@testable import DeveloperNews

@MainActor
@Suite struct PersistenceStoreTests {
    private func makeStore() -> PersistenceStore {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return PersistenceStore(defaults: defaults)
    }

    @Test func writesAndLoadsPersistedState() async {
        let store = makeStore()
        let item = StoreTestSupport.makeItem(
            urlString: "https://example.com/saved",
            topics: [.ios, .ai],
            trendScore: 42)
        let savedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let history = ReadRecord(
            url: item.url,
            title: item.title,
            sourceName: item.sourceName,
            readAt: savedAt)

        await store.saveTopics([.ios, .ai])
        await store.saveSavedItems(
            snapshots: [item.url: item],
            timestamps: [item.url: savedAt])
        await store.saveSortOrder(.trending)
        await store.saveNotificationsEnabled(true)
        await store.saveDisabledSourceCategories([.reddit])
        await store.saveBlockedUsers(["blocked-user"])
        await store.saveReadItems(
            readItemURLs: [item.url.absoluteString],
            readPostIds: ["post-1"])
        await store.saveReadHistory([history])
        await store.saveTranslationLanguage("ko")
        await store.saveReaderTextSize(.large)
        await store.saveDigestTime(DigestTime(minuteOfDay: 7 * 60 + 30))
        await store.saveLastUpdatedAt(savedAt)
        await store.saveHasSeenIntro(true)
        await store.saveTopStoryDismissedAt(savedAt)
        await store.saveAllItems([item])
        await store.saveImportedShareReceiptIDs(["share-1"])

        let loaded = store.load()

        #expect(loaded.selectedTopics == [.ios, .ai])
        #expect(loaded.savedItemSnapshots[item.url] == item)
        #expect(loaded.savedItemTimestampsByURL[item.url] == savedAt)
        #expect(loaded.savedSortOrder == .trending)
        #expect(loaded.notificationsEnabled)
        #expect(loaded.disabledSourceCategories == [.reddit])
        #expect(loaded.blockedUserIds == ["blocked-user"])
        #expect(loaded.readItemURLs == [item.url.absoluteString])
        #expect(loaded.readPostIds == ["post-1"])
        #expect(loaded.readHistory == [history])
        #expect(loaded.translationLanguage == "ko")
        #expect(loaded.readerTextSize == .large)
        #expect(loaded.digestTime == DigestTime(minuteOfDay: 7 * 60 + 30))
        #expect(loaded.lastUpdatedAt == savedAt)
        #expect(loaded.hasSeenIntro)
        #expect(loaded.topStoryDismissedAt == savedAt)
        #expect(loaded.allItems == [item])
        #expect(loaded.importedShareReceiptIDs == ["share-1"])
    }

    @Test func corruptedJSONFallsBackWithoutDiscardingOtherSettings() async {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set(Data("not-json".utf8), forKey: "savedItemSnapshots")
        defaults.set(Data("not-json".utf8), forKey: "offlineArticles")
        defaults.set(Data("not-json".utf8), forKey: "readHistory")
        defaults.set(Data("not-json".utf8), forKey: "allItems")
        let store = PersistenceStore(defaults: defaults)
        await store.saveTopics([.security])
        await store.saveNotificationsEnabled(true)

        let loaded = store.load()

        #expect(loaded.savedItemSnapshots.isEmpty)
        #expect(loaded.offlineArticles.isEmpty)
        #expect(loaded.readHistory.isEmpty)
        #expect(loaded.allItems.isEmpty)
        #expect(loaded.selectedTopics == [.security])
        #expect(loaded.notificationsEnabled)
    }
}
