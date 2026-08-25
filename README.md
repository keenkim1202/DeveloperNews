# DeveloperNews

[English](README.md) | [한국어](README.ko.md)

Every morning I used to hop between GitHub Trending, Hacker News, Reddit, and a pile of tech
blogs just to catch up. Got tired of it, so I built an app that does the hopping for me.

DeveloperNews pulls from five platforms plus 30 RSS feeds, scores everything by trend relevance,
and lets you browse by topic.
It also has a small community layer on top, so a story can be discussed rather than just read.

## Features

**Reading**

- Aggregates GitHub Trending, Hacker News, Reddit, Dev.to, and 30 RSS feeds
- Filter by topic — Web, iOS, Android, Backend, AI, Security, Product, Etc
- Trend scoring with per-source normalization and a cross-source mention boost
- On-device translation of titles and summaries via Apple's Translation framework
- Three-line article summary, generated on the device with Foundation Models
- Where a setting or region blocks a summary, the app names it; hardware that cannot run one
  has no button, with the reason in Settings

**Saving**

- Bookmarks with notes, search, and URL-level deduplication
- Share Extension — save an article from Safari or any other app
- Opening a bookmarked article keeps its text, so it still opens on a train with no signal.
  One saved from the Share Extension and never opened has nothing to show yet
- That kept text is searchable, so a saved article can be found by a phrase from its body
  rather than only by its title
- Reading history, newest first, for the article you did not think to save

**Widget, notifications, and Shortcuts**

- Home screen widget in three sizes, plus the Lock Screen and StandBy. A tap opens the story
  in the app's reader rather than Safari
- Ask Siri for the top story, or run the same thing from Spotlight and the Shortcuts app
- A daily notification with the story at the top of your feed

**Community**

- Post a story to the feed with your own commentary, or write a standalone post
- Discover (trending / recent) and Following feeds
- Comments with single-level replies, likes on both posts and comments
- Follow other users, browse follower and following lists, search by name
- Story-level engagement — like and comment counts attached to an article URL itself,
  independent of who posted it
- Activity inbox for likes, comments, replies, and new followers, with an unread badge
- Report and block, with a blocked-users list in Settings

**Account**

- Sign in with Apple, Google, or email
- Editable display name, emoji avatar, and bio
- Account deletion that clears the user's own content

## Architecture

### Content sources — strategy plus composite

Every source implements `ContentSourceClient`, so adding one is a matter of adding a conformance.

```
ContentSourceClient (protocol)
├── GitHubTrendingSourceClient
├── HackerNewsSourceClient
├── RedditSourceClient
├── DevToSourceClient
└── RSSSourceClient

CompositeContentSourceClient   <- also conforms to ContentSourceClient
  └── runs all of the above in parallel, then merges, scores, and deduplicates
```

`CompositeContentSourceClient` fans out with `withTaskGroup`.

Each fetch is wrapped so one failing source cannot take the reload down with it.
The app surfaces which sources were unavailable instead of showing an error page.

### Scoring pipeline

Raw metrics are not comparable across sources — GitHub has stars, Reddit has upvotes, Hacker
News has points. So the pipeline is:

1. **Source trust bonus** — a small fixed boost for sources worth surfacing
2. **Per-source normalization** — scores are rescaled within each source so the metrics become
   comparable
3. **Deduplication with a mention boost** — the same story from several sources collapses into
   one item and gains +4 per additional mention

### State and view models

`AppState` is the composition root.
The pieces it owns are split by concern rather than living in one object:

| Store | Owns |
|---|---|
| `FeedStore` | fetching, caching, pagination, and keeping the cached feed when a refresh fails |
| `SavedItemsStore` | bookmarks, sort order, snapshots |
| `ReadTracker` | read state, bounded to a fixed number of entries |
| `SourceCategoryStore` | which sources are switched on |

Screens go through view models.
Services sit behind protocols (`AuthServicing`, `CommunityServicing`, `FeedPostServicing`,
`ActivityServicing`, and so on), which is what lets the test target build an entire `AppState`
out of mocks.

### Community and real-time

Firebase Auth and Firestore back the user-generated side.
News fetching stays plain REST: Firestore is only used for what users write.

Comments, posts, and the activity inbox use `addSnapshotListener`, so a second device sees a
like as it happens.

### Activity inbox

There is no server.
The client that performs an action writes the notification into the recipient's inbox, which
means the security rules have to do the work a backend would otherwise do.

`firestore.rules` requires an activity to name evidence that its action actually happened:

- the actor is in the post's `likedBy`
- the comment exists and they wrote it

Each activity is also pinned to a document id derived from its own contents, so one real like
cannot be replayed into a hundred inbox rows.

`scripts/test-firestore-rules.py` exercises those rules against the Firestore emulator.
Each of its 33 checks is a denial a client cannot be trusted to make itself.

`.github/workflows/firestore-rules.yml` runs it on any pull request that touches the rules.
The deploy to Firebase is gated on it passing, so the rules and the code that needs them land
together.

To run it locally:

```bash
firebase emulators:exec --only firestore "python3 scripts/test-firestore-rules.py"
```

## Tech stack

| | |
|---|---|
| **Language** | Swift 6.0, strict concurrency with `MainActor` default isolation |
| **UI** | SwiftUI, `@Observable` |
| **Concurrency** | async/await, `TaskGroup`, actors |
| **Networking** | URLSession |
| **Backend** | Firebase (Auth, Firestore) |
| **Auth** | Apple, Google, email |
| **Translation** | Apple Translation framework, on-device |
| **Summaries** | Foundation Models, on-device |
| **Notifications** | UserNotifications, with BackgroundTasks keeping the daily digest current |
| **Tests** | Swift Testing |
| **Extensions** | Share Extension, Widget Extension |
| **System** | App Intents — Siri, Spotlight, Shortcuts |
| **CI/CD** | GitHub Actions, fastlane |

## Requirements

- iOS 26.0+
- Xcode 26+
- Swift 6.0

Firebase configuration is not committed.
Drop your own `GoogleService-Info.plist` into `DeveloperNews/` — without it the app launches but
the community features stay signed out.

## Tests

```bash
xcodebuild test -project DeveloperNews.xcodeproj -scheme DeveloperNews \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Pull requests run the same tests through `.github/workflows/pr-check.yml`, which picks the
newest available iPhone simulator on the runner.
Changes to `firestore.rules` additionally run the rules probe described above.

## License

MIT — see [LICENSE](LICENSE).

---

<details>
<summary><strong>Fastlane setup</strong></summary>

### Setup

```bash
bundle install
cp .env.default .env
```

### App Store Connect API key

Set these before using `beta` or `release`:

```bash
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
```

You can also fill in `fastlane/.env` locally:

```bash
cp .env.default fastlane/.env
```

For GitHub Actions, add these repository secrets:

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_KEY_CONTENT`
- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `KEYCHAIN_PASSWORD`

### Lanes

```bash
bundle exec fastlane ios ci
bundle exec fastlane ios simulator_build
bundle exec fastlane ios archive
bundle exec fastlane ios beta
bundle exec fastlane ios release
bundle exec fastlane ios bump_build
```

### Notes

- `ci` applies fastlane's CI setup when `CI` is set, then runs `simulator_build`
- `simulator_build` builds for iOS Simulator without archiving
- `archive` creates a device archive and exports `build/DeveloperNews.ipa`
- `beta` uploads to TestFlight; `release` uploads to App Store Connect without auto-submitting
- `beta` and `release` need the API key variables above
- `bump_build` takes the latest TestFlight build number for the current version and adds one
- Archive signing fetches provisioning profiles through the App Store Connect API and exports
  with explicit profile mappings
- Pushes to the `release` branch run `.github/workflows/release-beta.yml`
- Override the export method with `FL_EXPORT_METHOD` when needed

</details>
