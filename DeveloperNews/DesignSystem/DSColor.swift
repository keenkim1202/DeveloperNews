import SwiftUI

// Semantic color tokens for the app. Each token maps 1:1 to the system or asset
// color it replaces, so adopting these never changes the rendered appearance.
//
// Note: the hierarchical SwiftUI styles (.primary/.secondary/.tertiary) are the
// native semantic layer this design system builds on top of, so they are used
// directly at call sites rather than aliased here.
enum DSColor {
    // Brand tint, backed by the AccentColor asset.
    static let accent = Color.accentColor

    // Base background for full screens.
    static let background = Color(.systemBackground)

    // Raised surfaces such as cards, chips, and input fields.
    static let surface = Color(.secondarySystemBackground)

    // Subtle fill for placeholders and thumbnails.
    static let fill = Color(.tertiarySystemFill)

    // Destructive and error emphasis.
    static let destructive = Color.red

    // Content drawn on top of the accent tint.
    static let onAccent = Color.white

    // Dimming layer for toasts, overlays, and the comment input bar.
    static let scrim = Color.black
}
