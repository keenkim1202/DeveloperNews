import SwiftUI
import WebKit

struct PrivacyPolicyView: View {
    private static let notionURL = URL(static: "https://profuse-scaffold-962.notion.site/PrivacyInfo-34138d63664180fc9fb0d2604090aad5")

    var body: some View {
        SimpleWebView(url: Self.notionURL)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(.privacyPolicy)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
    }
}


struct SimpleWebView: UIViewRepresentable {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

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
                    sectionHeader(.useOfTheApp)
                    sectionBody(.developerNewsIsProvidedAsIsWithoutWarrantyOfAnyKindYouUseTheAppAtYourOwnDiscretion)

                    sectionHeader(.thirdPartyContent)
                    sectionBody(.headlinesSummariesThumbnailsAndLinksSurfacedInsideTheAppBelongToTheirOriginalPublishersTheFullArticleContentRemainsHostedByThePublisherAndIsOpenedInThePublishersOwnPageWhenYouTapAStory)

                    sectionHeader(.acceptableUse)
                    sectionBody(.youMayNotAttemptToReverseEngineerRedistributeOrScrapeContentFromTheAppUseTheInAppBrowserOnlyForPersonalNonCommercialReading)

                    sectionHeader(.limitationOfLiability)
                    sectionBody(.developerNewsIsNotResponsibleForTheAccuracyAvailabilityOrBehaviorOfThirdPartyContentSurfacedThroughTheAppIncludingAnyLinksOpenedInTheInAppBrowser)

                    sectionHeader(.changes)
                    sectionBody(.theseTermsMayBeUpdatedWhenMeaningfulProductChangesShipContinuedUseOfTheAppAfterAnUpdateConstitutesAcceptanceOfTheRevisedTerms)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(.termsOfUse)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func sectionHeader(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.headline)
    }

    private func sectionBody(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
    }
}

