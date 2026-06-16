# DeveloperNews

## Fastlane

This repo now includes a basic `fastlane` setup for local builds and App Store Connect delivery.

### Setup

```bash
bundle install
cp .env.default .env
```

### App Store Connect API Key

Set these environment variables before using `beta` or `release`:

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
bundle exec fastlane ios simulator_build
bundle exec fastlane ios ci
bundle exec fastlane ios archive
bundle exec fastlane ios beta
bundle exec fastlane ios release
bundle exec fastlane ios bump_build
```

### Notes

- `simulator_build` builds `DeveloperNews` for iOS Simulator without archiving.
- `ci` runs the pull request validation build and applies fastlane CI setup when `CI` is set.
- `archive` creates a device archive and exports `build/DeveloperNews.ipa`.
- `beta` uploads the archived build to TestFlight.
- `release` uploads the archived build to App Store Connect without auto-submitting for review.
- `beta` and `release` require the App Store Connect API Key environment variables above.
- `bump_build` uses the latest TestFlight build number for the current marketing version plus one and requires the App Store Connect API Key environment variables.
- archive signing uses App Store Connect API credentials to fetch provisioning profiles and exports with explicit profile mappings.
- pull requests run `.github/workflows/pr-check.yml`, which executes `bundle exec fastlane ios ci`.
- pushes to the `release` branch run `.github/workflows/release-beta.yml`, which executes `bundle exec fastlane ios beta`
- Override the export method with `FL_EXPORT_METHOD` when needed.
- Override the TestFlight changelog commit count with `FL_CHANGELOG_COMMITS` when needed.
- Override fastlane's Xcode build settings timeout with `FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT` and `FASTLANE_XCODEBUILD_SETTINGS_RETRIES` when needed.
