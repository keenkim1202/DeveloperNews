import Foundation
import Testing
@testable import DeveloperNews

// The widget builds these links from its own copy of the format, so the parser
// is the only place the two ends are checked against each other.
@MainActor
@Suite struct DeepLinkTests {
    private func widgetStyleLink(for article: String) -> URL {
        var components = URLComponents()
        components.scheme = "devnews"
        components.host = "article"
        components.queryItems = [URLQueryItem(name: "url", value: article)]
        return components.url!
    }

    @Test func parsesTheLinkTheWidgetBuilds() {
        let article = "https://example.com/a?ref=feed&x=1"

        let parsed = DeepLink.articleURL(from: widgetStyleLink(for: article))

        #expect(parsed?.absoluteString == article)
    }

    @Test func rejectsOtherSchemesAndHosts() {
        #expect(DeepLink.articleURL(from: URL(string: "https://example.com/a")!) == nil)
        #expect(DeepLink.articleURL(from: URL(string: "devnews://profile?url=https://a.com")!) == nil)
        #expect(DeepLink.articleURL(from: URL(string: "devnews://article")!) == nil)
    }

    // The payload comes from outside the app, so a link that would send the
    // reader somewhere other than the web is refused.
    @Test func rejectsANonWebPayload() {
        #expect(DeepLink.articleURL(from: widgetStyleLink(for: "file:///etc/passwd")) == nil)
        #expect(DeepLink.articleURL(from: widgetStyleLink(for: "javascript:alert(1)")) == nil)
    }
}
