import Foundation

protocol ContentSourceClient {
    func fetchItems() async throws -> [ContentItem]
}

struct MockContentSourceClient: ContentSourceClient {
    func fetchItems() async throws -> [ContentItem] {
        try await Task.sleep(for: .milliseconds(350))
        return SampleData.items
    }
}
