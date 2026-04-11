import Foundation

protocol ContentSourceClient {
    func fetchItems() -> [ContentItem]
}

struct MockContentSourceClient: ContentSourceClient {
    func fetchItems() -> [ContentItem] {
        SampleData.items
    }
}
