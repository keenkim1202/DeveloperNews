import Foundation

/// Cross-process queue used by the Share Extension and the main app.
/// `NSFileCoordinator` serializes each read-modify-write operation so an append
/// cannot be overwritten while the app drains previously shared items.
struct PendingSharedItemQueue {
    typealias Entry = [String: String]

    static let fileName = "pending-shared-items.json"

    private let fileURL: URL

    init?(appGroupIdentifier: String) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        else {
            return nil
        }
        self.init(directoryURL: containerURL)
    }

    init(directoryURL: URL) {
        fileURL = directoryURL.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    func append(_ entry: Entry) throws {
        try coordinateWrite { coordinatedURL in
            var entries = try load(from: coordinatedURL)
            entries.append(entry)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: coordinatedURL, options: .atomic)
        }
    }

    /// Returns a coordinated snapshot without removing it. The caller removes
    /// these entries only after their destination write is durable.
    func read() throws -> [Entry] {
        var entries: [Entry] = []
        try coordinateWrite { coordinatedURL in
            guard FileManager.default.fileExists(atPath: coordinatedURL.path) else {
                return
            }
            entries = try load(from: coordinatedURL)
        }
        return entries
    }

    /// Removes only the supplied snapshot. Entries appended after `read()` have
    /// different ids and remain queued for the next processing pass.
    func acknowledge(_ processed: [Entry]) throws {
        let processedIDs = Set(processed.compactMap(Self.identity))
        guard !processedIDs.isEmpty else { return }

        try coordinateWrite { coordinatedURL in
            let remaining = try load(from: coordinatedURL).filter { entry in
                guard let id = Self.identity(entry) else { return true }
                return !processedIDs.contains(id)
            }
            if remaining.isEmpty {
                if FileManager.default.fileExists(atPath: coordinatedURL.path) {
                    try FileManager.default.removeItem(at: coordinatedURL)
                }
            }
            else {
                let data = try JSONEncoder().encode(remaining)
                try data.write(to: coordinatedURL, options: .atomic)
            }
        }
    }

    /// Removes queued shares for a bookmark that the user explicitly deleted.
    func acknowledge(url: URL) throws {
        try coordinateWrite { coordinatedURL in
            let remaining = try load(from: coordinatedURL).filter { entry in
                entry["url"] != url.absoluteString
            }
            if remaining.isEmpty {
                if FileManager.default.fileExists(atPath: coordinatedURL.path) {
                    try FileManager.default.removeItem(at: coordinatedURL)
                }
            }
            else {
                let data = try JSONEncoder().encode(remaining)
                try data.write(to: coordinatedURL, options: .atomic)
            }
        }
    }

    private func load(from url: URL) throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    private static func identity(_ entry: Entry) -> String? {
        entry["id"] ?? entry["url"]
    }

    private func coordinateWrite(_ operation: (URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?

        coordinator.coordinate(
            writingItemAt: fileURL,
            options: .forMerging,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try operation(coordinatedURL)
            }
            catch {
                operationError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }
}
