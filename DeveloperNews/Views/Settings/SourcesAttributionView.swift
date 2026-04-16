import SwiftUI

struct SourcesAttributionView: View {
    var body: some View {
        List {
            Section {
                Text("DeveloperNews aggregates publicly available developer content. We display headlines, short excerpts, and links — full articles open in the publisher's website inside the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Blogs & Articles") {
                Text("Curated RSS feeds from independent and company engineering blogs.")
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

            Section("Hacker News") {
                Text("Headlines from the public Hacker News API operated by Y Combinator.")
                    .font(.footnote)
                attributionRow("Hacker News", url: "https://news.ycombinator.com")
            }

            Section("GitHub Trending") {
                Text("Trending repositories from the public GitHub Search API.")
                    .font(.footnote)
                attributionRow("GitHub", url: "https://github.com")
            }

            Section("Reddit") {
                Text("Link posts from a curated set of developer subreddits via Reddit's public listing JSON.")
                    .font(.footnote)
                attributionRow("Reddit", url: "https://www.reddit.com")
            }

            Section {
                Text("All trademarks and logos belong to their respective owners. DeveloperNews is not affiliated with or endorsed by any of the listed sources.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Content sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func attributionRow(_ name: String, url: String) -> some View {
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

