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

You can also fill in `.env` locally:

```bash
cp .env.default .env
```

For GitHub Actions, add these repository secrets:

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_KEY_CONTENT`

### Lanes

```bash
bundle exec fastlane ios simulator_build
bundle exec fastlane ios archive
bundle exec fastlane ios beta
bundle exec fastlane ios release
bundle exec fastlane ios bump_build
```

### Notes

- `simulator_build` builds `DeveloperNews` for iOS Simulator without archiving.
- `archive` creates a device archive and exports `build/DeveloperNews.ipa`.
- `beta` uploads the archived build to TestFlight.
- `release` uploads the archived build to App Store Connect without auto-submitting for review.
- `beta` and `release` require the App Store Connect API Key environment variables above.
- pushes to the `release` branch run `.github/workflows/release-beta.yml`, which executes `bundle exec fastlane ios beta`
- Override the export method with `FL_EXPORT_METHOD` when needed.
