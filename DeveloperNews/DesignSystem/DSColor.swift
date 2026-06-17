import SwiftUI

// Semantic color tokens for the app. Each token maps 1:1 to the system or asset
// color it replaces, so adopting these never changes the rendered appearance.
//
// Note: the hierarchical SwiftUI styles (.primary/.secondary/.tertiary) are the
// native semantic layer this design system builds on top of, so they are used
// directly at call sites rather than aliased here.
enum DSColor {
    static let accent = Color.accentColor

    static let background = Color(.systemBackground)

    static let surface = Color(.secondarySystemBackground)

    static let fill = Color(.tertiarySystemFill)

    static let destructive = Color.red

    static let onAccent = Color.white

    static let scrim = Color.black
}
