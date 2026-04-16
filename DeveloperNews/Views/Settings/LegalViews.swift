import SwiftUI
import WebKit

struct PrivacyPolicyView: View {
    private static let notionURL = URL(string: "https://profuse-scaffold-962.notion.site/PrivacyInfo-34138d63664180fc9fb0d2604090aad5")!

    var body: some View {
        SimpleWebView(url: Self.notionURL)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Privacy policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}


struct SimpleWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}


struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    sectionHeader("Use of the app")
                    sectionBody("DeveloperNews is provided as is, without warranty of any kind. You use the app at your own discretion.")

                    sectionHeader("Third party content")
                    sectionBody("Headlines, summaries, thumbnails, and links surfaced inside the app belong to their original publishers. The full article content remains hosted by the publisher and is opened in the publisher's own page when you tap a story.")

                    sectionHeader("Acceptable use")
                    sectionBody("You may not attempt to reverse engineer, redistribute, or scrape content from the app. Use the in-app browser only for personal, non commercial reading.")

                    sectionHeader("Limitation of liability")
                    sectionBody("DeveloperNews is not responsible for the accuracy, availability, or behavior of third party content surfaced through the app, including any links opened in the in-app browser.")

                    sectionHeader("Changes")
                    sectionBody("These terms may be updated when meaningful product changes ship. Continued use of the app after an update constitutes acceptance of the revised terms.")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Terms of use")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func sectionBody(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
    }
}

