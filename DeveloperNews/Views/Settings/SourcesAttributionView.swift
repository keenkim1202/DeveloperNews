import SwiftUI

struct SourcesAttributionView: View {
    var body: some View {
        List {
            Section {
                Text(.developerNewsAggregatesPubliclyAvailableDeveloperContentWeDisplayHeadlinesShortExcerptsAndLinksFullArticlesOpenInThePublishersWebsiteInsideTheApp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(.blogsArticles) {
                Text(.curatedRssFeedsFromIndependentAndCompanyEngineeringBlogs)
                    .font(.footnote)
                attributionRow("Swift with Majid", url: "https://swiftwithmajid.com")
                attributionRow("InfoQ", url: "https://www.infoq.com")
                attributionRow("GitHub Blog", url: "https://github.blog")
                attributionRow("Mozilla Hacks", url: "https://hacks.mozilla.org")
                attributionRow("Cloudflare Blog", url: "https://blog.cloudflare.com")
                attributionRow("Lobsters", url: "https://lobste.rs")
                attributionRow("Stripe Engineering", url: "https://stripe.com/blog")
                attributionRow("Netflix Tech Blog", url: "https://netflixtechblog.com")
                attributionRow("High Scalability", url: "https://www.highscalability.com")
                attributionRow("Stack Overflow Blog", url: "https://stackoverflow.blog")
                attributionRow("CSS-Tricks", url: "https://css-tricks.com")
                attributionRow("Hacking with Swift", url: "https://www.hackingwithswift.com")
                attributionRow("Donny Wals", url: "https://www.donnywals.com")
            }

            Section(.hackerNews) {
                Text(.headlinesFromThePublicHackerNewsApiOperatedByYCombinator)
                    .font(.footnote)
                attributionRow(.hackerNews, url: "https://news.ycombinator.com")
            }

            Section(.gitHubTrending) {
                Text(.trendingRepositoriesFromThePublicGitHubSearchApi)
                    .font(.footnote)
                attributionRow("GitHub", url: "https://github.com")
            }

            Section(.reddit) {
                Text(.linkPostsFromACuratedSetOfDeveloperSubredditsViaRedditsPublicListingJson)
                    .font(.footnote)
                attributionRow(.reddit, url: "https://www.reddit.com")
            }

            Section {
                Text(.allTrademarksAndLogosBelongToTheirRespectiveOwnersDeveloperNewsIsNotAffiliatedWithOrEndorsedByAnyOfTheListedSources)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(.contentSources)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func attributionRow(_ name: LocalizedStringResource, url: String) -> some View {
        if let resolved = URL(string: url) {
            Link(destination: resolved) {
                HStack {
                    Text(name)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
        }
        else {
            Text(name)
        }
    }
}

