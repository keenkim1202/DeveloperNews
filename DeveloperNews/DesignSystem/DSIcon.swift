import SwiftUI

// Semantic SF Symbol tokens for icons used in views. The rawValue is the exact
// system symbol name used before, so adopting these never changes appearance.
//
// Domain icon maps (Topic.symbolName, SourceCategory.symbolName,
// ContentItem.Kind.symbolName) stay in the model layer and are not routed here.
enum DSIcon: String {
    case close = "xmark"
    case add = "plus"
    case edit = "pencil"
    case delete = "trash"
    case more = "ellipsis"
    case share = "square.and.arrow.up"
    case refresh = "arrow.clockwise"
    case copy = "doc.on.doc"
    case camera = "camera.circle.fill"
    case sortToggle = "arrow.up.arrow.down.circle"
    case chevronForward = "chevron.right"
    case externalLinkSquare = "arrow.up.forward.square"
    case externalLinkUpRight = "arrow.up.right.square"

    case like = "heart"
    case likeFilled = "heart.fill"
    case bookmark = "bookmark"
    case bookmarkFilled = "bookmark.fill"
    case checkboxChecked = "checkmark.square.fill"
    case checkboxUnchecked = "square"

    case translate = "translate"
    case photo = "photo"
    case newspaper = "newspaper"
    case comment = "bubble.right"
    case commentAlt = "bubble.left"
    case upvote = "arrow.up"
    case sparkles = "sparkles"
    case checkmarkCircleFill = "checkmark.circle.fill"
    case unknown = "questionmark.circle.dashed"
    case sendFilled = "arrow.up.circle.fill"
    case noteAdd = "note.text.badge.plus"
    case note = "note.text"
    case networkError = "wifi.exclamationmark"

    case safari = "safari"
    case globe = "globe"
    case blockedUsers = "person.slash"
    case document = "doc.text"
    case privacy = "hand.raised"
    case terms = "doc.plaintext"
    case feedback = "envelope"
    case emoji = "face.smiling"
    case account = "person.crop.circle"
    case allTopics = "square.grid.2x2"
    case emptyTray = "tray"
    case community = "person.2"
    case quote = "quote.bubble"
}

extension Image {
    init(_ icon: DSIcon) {
        self.init(systemName: icon.rawValue)
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringResource, icon: DSIcon) {
        self.init(systemName: icon.rawValue) {
            Text(title)
        }
    }

    private init(
        systemName: String,
        @ViewBuilder title: () -> Text,
    ) {
        self.init(
            title: title,
            icon: {
                Image(systemName: systemName)
            })
    }
}
