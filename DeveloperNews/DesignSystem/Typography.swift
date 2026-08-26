import SwiftUI

// Brand and semantic font tokens, each mapping 1:1 to the font it replaces, so
// appearance is unchanged. Only the weighted styles that recur are named here;
// a single standard style stays inline at its call site.
extension Font {
    static let keenPixelTitle = Font.custom("PixelifySans-Regular", size: 26)

    static let dsCardTitle = Font.subheadline.weight(.semibold)

    static let dsLabel = Font.caption.weight(.semibold)

    static let dsTag = Font.caption2.weight(.medium)

    static let dsButton = Font.body.weight(.medium)
}
