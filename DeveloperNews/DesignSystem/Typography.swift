import SwiftUI

// Brand and semantic font tokens. The brand font carries the app's identity; the
// semantic tokens name the weighted standard styles that recur across the views.
// Each token maps 1:1 to the exact font it replaces, so appearance is unchanged.
//
// Single standard styles (.headline, .body, .caption, .title2.bold(), ...) stay
// inline at call sites and are not tokenized.
extension Font {
    // Pixel brand font used for the splash wordmark.
    static let keenPixelTitle = Font.custom("PixelifySans-Regular", size: 26)

    // Title of a card or row.
    static let dsCardTitle = Font.subheadline.weight(.semibold)

    // Emphasized metadata such as counts, badges, and inline labels.
    static let dsLabel = Font.caption.weight(.semibold)

    // Small de-emphasized metadata such as topic tags and timestamps.
    static let dsTag = Font.caption2.weight(.medium)

    // Emphasized body text for buttons and prominent rows.
    static let dsButton = Font.body.weight(.medium)
}
