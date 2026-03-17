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
