import Foundation

/// The `devnews://` links the widget hands back to the app.
///
/// The widget builds these with its own copy of the format, the same way it
/// agrees with the app on the story payload — the two ends share no code.
enum DeepLink {
    static let scheme = "devnews"
    private static let articleHost = "article"
    private static let urlQueryItem = "url"

    /// The article a widget tap is asking for, or nil for anything else.
    static func articleURL(from incoming: URL) -> URL? {
        guard incoming.scheme == scheme,
              incoming.host == articleHost,
              let components = URLComponents(url: incoming, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == urlQueryItem })?.value,
              let target = URL(string: raw),
              target.scheme == "https" || target.scheme == "http"
        else { return nil }
        return target
    }
}
