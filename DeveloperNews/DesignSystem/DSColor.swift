import SwiftUI

// Semantic color tokens. Each maps 1:1 to the system or asset color it replaces,
// so adopting one never changes what is rendered. The hierarchical SwiftUI styles
// (.primary/.secondary/.tertiary) are the layer underneath and stay at call sites.
enum DSColor {
    static let accent = Color.accentColor

    static let background = Color(.systemBackground)

    static let surface = Color(.secondarySystemBackground)

    static let fill = Color(.tertiarySystemFill)

    static let destructive = Color.red

    static let onAccent = Color.white

    static let scrim = Color.black
}
