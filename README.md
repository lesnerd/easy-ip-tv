# EasyIpTv

A multi-platform IPTV app built with SwiftUI for iOS, iPadOS, macOS, and tvOS.

## Features

- **Home Screen** - Personalized landing page with Continue Watching, Trending Movies, Trending Series, and Trending Live TV
  - Resume movies and shows exactly where you left off
  - Auto-suggests the next episode when you finish one
  - Trending content ranked by rating with bold numbered cards (Apple TV style)
- **Live TV** - Browse and watch live TV channels organized by categories
- **Movies** - Access your VOD movie library with rich detail views (cast, director, genre)
- **Shows** - Browse TV series with season and episode navigation
- **Favorites** - Quick access to your favorite content from the Home screen
  - Long-press any channel, movie, or show to add/remove from favorites
- **Freemium Model** - Free tier with ads; Premium ($11.90/year) for ad-free, unlimited playlists/favorites, and more
- **Multi-language Support** - English, Hungarian (Magyar), and Hebrew (עברית) with RTL support
- **Multiple Playlist Inputs** - M3U/M3U8, Xtream Codes, and Stalker Portal (MAC-based)
- **VLCKit Playback** - Robust video playback for all container formats (MKV, TS, etc.)
- **Channel Navigation** - Easy channel switching while watching live TV
  - Swipe up/down to show channel navigator
  - Channel up/down for quick switching

## Requirements

- iOS 17.0+ / iPadOS 17.0+ / macOS 14.0+ / tvOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Getting Started

1. Open `EasyIpTv.xcodeproj` in Xcode
2. Select the Apple TV simulator or your Apple TV device
3. Build and run the project
4. Go to **Settings** and add your M3U playlist URL

## M3U Playlist Format

The app supports standard M3U/M3U8 playlists with the following format:

```
#EXTM3U
#EXTINF:-1 tvg-id="channel1" tvg-name="Channel Name" tvg-logo="http://logo.url/logo.png" group-title="Category",Channel Name
http://stream.url/live/channel.m3u8
```

### Content Type Detection

The app automatically categorizes content based on group titles:
- **Live TV**: Default for most content
- **Movies**: Groups containing "movie", "film", or "vod"
- **Shows**: Groups containing "series", "show", or "episode"

## Project Structure

```
EasyIpTv/
├── App/
│   └── EasyIpTvApp.swift          # App entry point
├── Models/
│   ├── Channel.swift              # Live TV channel model
│   ├── Movie.swift                # Movie model
│   ├── Show.swift                 # TV show and episode models
│   ├── M3UItem.swift              # M3U parser item model
│   ├── ContentType.swift          # Content type enum
│   └── ContentCategory.swift      # Category and favorites models
├── Views/
│   ├── MainMenuView.swift         # Tab navigation
│   ├── Home/                      # Home screen (Continue Watching, Trending)
│   ├── LiveTV/                    # Live TV views
│   ├── Movies/                    # Movies views
│   ├── Shows/                     # Shows views
│   ├── Favorites/                 # Favorites view
│   ├── Player/                    # Video player (AVPlayer + VLCKit)
│   ├── Settings/                  # Settings and upgrade views
│   └── Components/                # Reusable UI components
├── ViewModels/
│   ├── ContentViewModel.swift     # Content management
│   ├── FavoritesViewModel.swift   # Favorites management
│   └── PlayerViewModel.swift      # Playback control
├── Services/
│   ├── M3UParser.swift            # M3U playlist parser
│   ├── StreamService.swift        # Video streaming service
│   └── StorageService.swift       # Local storage (UserDefaults)
├── Localization/
│   ├── LocalizationManager.swift  # Language management
│   └── Localizable.xcstrings      # String translations
└── Resources/
    └── Assets.xcassets            # App icons and colors
```

## Navigation

### Remote Control
- **Swipe**: Navigate between items
- **Click/Press**: Select item
- **Long Press**: Toggle favorite
- **Play/Pause**: Control playback
- **Menu**: Back / Exit

### While Watching
- **Swipe Up/Down**: Show channel navigator (Live TV)
- **Swipe Left/Right**: Seek backward/forward (Movies/Shows)
- **Click**: Toggle controls visibility
- **Menu**: Exit player

## Localization

The app supports three languages:
- English (en) - Default
- Hungarian (hu) - Magyar
- Hebrew (he) - עברית (with RTL layout)

Change the language in Settings > Language.

## Data Storage

All user data is stored locally using UserDefaults:
- Favorite channels, movies, and shows
- Watch progress for movies and episodes
- Playlist URLs
- Language preference
- Stream quality setting

## License

This project is for personal use.

---

## CI/CD Pipeline

This repository uses GitHub Actions to automate building, testing, releasing, and deploying the Easy IPTV app across macOS, iOS, and tvOS platforms.

### Pipeline Overview

The CI/CD pipeline consists of four main workflows:

1. **Build** (`.github/workflows/build.yml`)
   - Triggers on: Push to `main` branch, Pull Requests
   - Builds the app for all platforms (macOS, iOS, tvOS)
   - Runs on every code change to ensure builds are working

2. **Lint** (`.github/workflows/lint.yml`)
   - Triggers on: Pull Requests with Swift file changes
   - Runs SwiftLint to enforce code style and quality standards
   - Ensures code follows project conventions

3. **Release** (`.github/workflows/release.yml`)
   - Triggers on: Git tags matching `v*` (e.g., `v1.0.0`, `v1.0.0-beta1`)
   - Builds signed release artifacts for all platforms
   - Creates GitHub Release with downloadable builds
   - Supports code signing with Apple Distribution certificates

4. **Deploy** (`.github/workflows/deploy.yml`)
   - Triggers on: Git tags matching `v*` or manual workflow dispatch
   - Archives and exports apps for App Store distribution
   - Uploads to App Store Connect / TestFlight
   - Routes to staging (TestFlight) or production (App Store) environments

### Setting Up Code Signing

To enable code signing for releases and deployments, configure the following GitHub Secrets in your repository settings (**Settings > Secrets and variables > Actions > New repository secret**):

#### Required Secrets

1. **`CERTIFICATE_BASE64`**: Base64-encoded Apple Distribution certificate (`.p12` file)
   ```bash
   base64 -i Certificates.p12 | pbcopy  # macOS - copies to clipboard
   base64 -i Certificates.p12           # Linux - outputs to terminal
   ```

2. **`CERTIFICATE_PASSWORD`**: Password for the certificate `.p12` file

3. **`PROVISIONING_PROFILE_IOS_BASE64`**: Base64-encoded iOS provisioning profile
   ```bash
   base64 -i iOS_Distribution.mobileprovision | pbcopy
   ```

4. **`PROVISIONING_PROFILE_MACOS_BASE64`**: Base64-encoded macOS provisioning profile
   ```bash
   base64 -i macOS_Distribution.provisionprofile | pbcopy
   ```

5. **`PROVISIONING_PROFILE_TVOS_BASE64`**: Base64-encoded tvOS provisioning profile
   ```bash
   base64 -i tvOS_Distribution.mobileprovision | pbcopy
   ```

#### App Store Connect API Secrets

For deploying to TestFlight and the App Store, you need App Store Connect API credentials:

1. **`APP_STORE_CONNECT_API_KEY_ID`**: Your API Key ID from App Store Connect
   - Go to [App Store Connect > Users and Access > Keys](https://appstoreconnect.apple.com/access/api)
   - Create or use an existing API key
   - Copy the Key ID (e.g., `ABC123XYZ4`)

2. **`APP_STORE_CONNECT_API_ISSUER_ID`**: Your Issuer ID from App Store Connect
   - Found on the same Keys page (e.g., `12345678-1234-1234-1234-123456789012`)

3. **`APP_STORE_CONNECT_API_KEY_BASE64`**: Base64-encoded App Store Connect API Key (`.p8` file)
   ```bash
   base64 -i AuthKey_ABC123XYZ4.p8 | pbcopy
   ```

### Configuring Deployment Environments

The deploy workflow uses GitHub deployment environments to control releases:

1. **Navigate to Repository Settings**
   - Go to **Settings > Environments**

2. **Create `staging` Environment**
   - Click "New environment"
   - Name: `staging`
   - Used for: TestFlight / beta deployments
   - No approval required (deploys automatically)

3. **Create `production` Environment**
   - Click "New environment"
   - Name: `production`
   - Used for: App Store production releases
   - **Recommended**: Add protection rules
     - Check "Required reviewers" and add team members who should approve production deployments
     - Optionally set "Wait timer" for a delay before deployment

### Triggering a Release and Deployment

#### Automatic Release and Deployment

1. **Create and push a version tag**:
   ```bash
   # For a beta/staging release (deploys to TestFlight)
   git tag v1.0.0-beta1
   git push origin v1.0.0-beta1

   # For a release candidate (deploys to TestFlight)
   git tag v1.0.0-rc1
   git push origin v1.0.0-rc1

   # For a production release (deploys to App Store)
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **What happens next**:
   - The **Release** workflow builds signed artifacts for all platforms
   - Creates a GitHub Release with downloadable builds
   - The **Deploy** workflow automatically triggers:
     - Tags with `-beta` or `-rc` → Deploy to **staging** (TestFlight)
     - Stable tags (e.g., `v1.0.0`) → Deploy to **production** (App Store)
   - If production has approval rules, reviewers must approve before deployment

#### Manual Deployment

You can also manually trigger a deployment from the GitHub Actions tab:

1. Go to **Actions > Deploy**
2. Click "Run workflow"
3. Select:
   - **Branch/Tag**: Choose the tag or branch to deploy
   - **Platform**: Select `all`, `iOS`, `macOS`, or `tvOS`
   - **Environment**: Choose `staging` or `production`
4. Click "Run workflow"

### Staging vs. Production Deployments

| Aspect | Staging (TestFlight) | Production (App Store) |
|--------|---------------------|------------------------|
| **Environment** | `staging` | `production` |
| **Triggered by** | Tags with `-beta` or `-rc` | Stable version tags (e.g., `v1.0.0`) |
| **Distribution** | TestFlight for internal/external testing | Public App Store release |
| **Approval** | None (automatic) | Recommended (configured in environment) |
| **Audience** | Beta testers via TestFlight | All App Store users |
| **Review** | No App Review required for TestFlight builds | Requires Apple App Review |

### Workflow Status Badges

Add these badges to show build status:

```markdown
![Build](https://github.com/lesnerd/easy-ip-tv/workflows/Build/badge.svg)
![Lint](https://github.com/lesnerd/easy-ip-tv/workflows/Lint/badge.svg)
![Release](https://github.com/lesnerd/easy-ip-tv/workflows/Release/badge.svg)
```

### Troubleshooting

**Build failures after adding code signing:**
- Verify all secrets are set correctly (base64 encoding without line breaks)
- Ensure provisioning profiles match your bundle identifier
- Check that certificates are not expired

**Deployment failures:**
- Verify App Store Connect API credentials are correct
- Ensure the app's bundle ID is registered in App Store Connect
- Check that the app version/build number is incremented

**Environment approval not working:**
- Go to Settings > Environments and add "Required reviewers"
- Ensure reviewers have appropriate repository permissions
