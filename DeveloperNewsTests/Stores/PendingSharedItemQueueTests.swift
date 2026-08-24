import Foundation
import Testing
@testable import DeveloperNews

@MainActor
@Suite struct PendingSharedItemQueueTests {
    @Test func acknowledgesOnlyItemsReadBeforeTheDurableSave() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstQueue = PendingSharedItemQueue(directoryURL: directory)
        let secondQueue = PendingSharedItemQueue(directoryURL: directory)

        try firstQueue.append(["id": "1", "url": "https://example.com/1"])
        try secondQueue.append(["id": "2", "url": "https://example.com/2"])

        let snapshot = try firstQueue.read()
        try secondQueue.append(["id": "3", "url": "https://example.com/3"])

        #expect(snapshot.compactMap { $0["id"] } == ["1", "2"])
        #expect(try secondQueue.read().compactMap { $0["id"] } == ["1", "2", "3"])

        try firstQueue.acknowledge(snapshot)

        #expect(try secondQueue.read().compactMap { $0["id"] } == ["3"])
    }

    @Test func acknowledgesAllQueuedEntriesForDeletedURL() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = PendingSharedItemQueue(directoryURL: directory)
        let deletedURL = try #require(URL(string: "https://example.com/deleted"))

        try queue.append(["id": "1", "url": deletedURL.absoluteString])
        try queue.append(["id": "2", "url": deletedURL.absoluteString])
        try queue.append(["id": "3", "url": "https://example.com/kept"])

        try queue.acknowledge(url: deletedURL)

        #expect(try queue.read().compactMap { $0["id"] } == ["3"])
    }
}
