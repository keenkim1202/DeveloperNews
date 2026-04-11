import Foundation

enum Topic: String, CaseIterable, Identifiable, Hashable {
    case web
    case ios
    case android
    case backend
    case ai
    case devops
    case security
    case product

    var id: String { rawValue }

    var title: String {
        switch self {
        case .web: "Web"
        case .ios: "iOS"
        case .android: "Android"
        case .backend: "Backend"
        case .ai: "AI"
        case .devops: "DevOps"
        case .security: "Security"
        case .product: "Product"
        }
    }

    var symbolName: String {
        switch self {
        case .web: "globe"
        case .ios: "iphone"
        case .android: "ladybug"
        case .backend: "server.rack"
        case .ai: "sparkles"
        case .devops: "shippingbox"
        case .security: "lock.shield"
        case .product: "square.stack.3d.up"
        }
    }
}

struct ContentItem: Identifiable, Hashable {
    enum Kind: String {
        case article
        case discussion
    }

    let id: UUID
    let kind: Kind
    let title: String
    let summary: String
    let sourceName: String
    let authorName: String?
    let url: URL
    let publishedAt: Date
    let topics: [Topic]
    let trendScore: Int
}
