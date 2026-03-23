import Foundation
import SwiftUI

/// Supported app languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case hungarian = "hu"
    case hebrew = "he"
    
    var id: String { rawValue }
    
    /// Display name in the language itself
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .hungarian: return "Magyar"
        case .hebrew: return "עברית"
        }
    }
    
    /// Display name in English
    var englishName: String {
        switch self {
        case .english: return "English"
        case .hungarian: return "Hungarian"
        case .hebrew: return "Hebrew"
        }
    }
    
    /// Whether this language is RTL
    var isRTL: Bool {
        self == .hebrew
    }
    
    /// Locale for the language
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// Manager for handling app localization
@MainActor
class LocalizationManager: ObservableObject {
    
    static let shared = LocalizationManager()
    
    /// Non-isolated bundle for string lookups (Bundle is thread-safe for reading)
    nonisolated(unsafe) static var currentBundle: Bundle = .main
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            StorageService.shared.saveSelectedLanguage(currentLanguage)
            updateBundle()
        }
    }
    
    /// The bundle for the currently selected language
    private(set) var bundle: Bundle = .main
    
    private init() {
        // Load saved language or use system default
        let savedLanguage = StorageService.shared.getSelectedLanguage()
        self.currentLanguage = savedLanguage
        updateBundle()
    }
    
    /// Sets the current language
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    /// Gets the layout direction for current language
    var layoutDirection: LayoutDirection {
        currentLanguage.isRTL ? .rightToLeft : .leftToRight
    }
    
    private func updateBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
            Self.currentBundle = bundle
        } else {
            self.bundle = .main
            Self.currentBundle = .main
        }
    }
}

// MARK: - Localized String Helper

/// Looks up a localized string using the in-app selected language bundle.
/// Uses the static `currentBundle` which is safe to read from any context.
private func tr(_ key: String) -> String {
    NSLocalizedString(key, bundle: LocalizationManager.currentBundle, comment: "")
}

/// Looks up a localized format string and applies arguments
private func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: LocalizationManager.currentBundle, comment: "")
    return String(format: format, arguments: args)
}

// MARK: - Localized Strings

/// Namespace for localized strings used throughout the app.
/// All strings resolve against the in-app selected language, not the system locale.
enum L10n {
    
    // MARK: - Navigation
    enum Navigation {
        static var home: String { tr("Home") }
        static var favorites: String { tr("Favorites") }
        static var liveTV: String { tr("Live TV") }
        static var movies: String { tr("Movies") }
        static var shows: String { tr("Shows") }
        static var downloads: String { tr("Downloads") }
        static var settings: String { tr("Settings") }
        static var more: String { tr("More") }
    }
    
    // MARK: - Player
    enum Player {
        static var play: String { tr("Play") }
        static var pause: String { tr("Pause") }
        static var stop: String { tr("Stop") }
        static var channelUp: String { tr("Channel Up") }
        static var channelDown: String { tr("Channel Down") }
        static var nowPlaying: String { tr("Now Playing") }
        static var loading: String { tr("Loading...") }
        static var buffering: String { tr("Buffering...") }
        static var resume: String { tr("Resume") }
        static var startOver: String { tr("Start Over") }
        static func resumeFrom(_ time: String) -> String { tr("Resume from %@?", time) }
        static var subtitles: String { tr("Subtitles") }
        static var off: String { tr("Off") }
        static var upNext: String { tr("Up Next") }
        static var autoPlayNext: String { tr("Auto-Play Next Episode") }
    }
    
    // MARK: - Favorites
    enum Favorites {
        static var addToFavorites: String { tr("Add to Favorites") }
        static var removeFromFavorites: String { tr("Remove from Favorites") }
        static var noFavorites: String { tr("No favorites yet") }
        static var noFavoritesDescription: String { tr("Long press on any channel, movie, or show to add it to your favorites.") }
    }
    
    // MARK: - Settings
    enum Settings {
        static var language: String { tr("Language") }
        static var playlists: String { tr("Playlists") }
        static var addPlaylist: String { tr("Add Playlist") }
        static var removePlaylist: String { tr("Remove Playlist") }
        static var enterPlaylistURL: String { tr("Enter playlist URL") }
        static var quality: String { tr("Quality") }
        static var subtitleLanguage: String { tr("Subtitle Language") }
        static var about: String { tr("About") }
        static var version: String { tr("Version") }
        static var clearData: String { tr("Clear All Data") }
        static var clearDataConfirmation: String { tr("Are you sure you want to clear all data? This action cannot be undone.") }
    }
    
    // MARK: - Content
    enum Content {
        static var allChannels: String { tr("All Channels") }
        static var allMovies: String { tr("All Movies") }
        static var allShows: String { tr("All Shows") }
        static var categories: String { tr("Categories") }
        static var recentlyWatched: String { tr("Recently Watched") }
        static var continueWatching: String { tr("Continue Watching") }
        static var featured: String { tr("Featured") }
        static var seeAll: String { tr("See All") }
        static var noResults: String { tr("No Results") }
        static var trendingMovies: String { tr("Trending Movies") }
        static var trendingSeries: String { tr("Trending Series") }
        static var trendingLiveTV: String { tr("Trending Live TV") }
        static var myFavorites: String { tr("My Favorites") }
        static var upNext: String { tr("Up Next") }
        static func season(_ number: Int) -> String { tr("Season %lld", number) }
        static func episode(_ number: Int) -> String { tr("Episode %lld", number) }
        static func seasonEpisode(_ season: Int, _ episode: Int) -> String {
            tr("S%lld E%lld", season, episode)
        }
        static func duration(_ minutes: Int) -> String { tr("%lld min", minutes) }
        static func episodeCount(_ count: Int) -> String { tr("%lld episodes", count) }
        static func minutesLeft(_ minutes: Int) -> String { tr("%lld min left", minutes) }
    }
    
    // MARK: - Errors
    enum Errors {
        static var loadingFailed: String { tr("Failed to load content") }
        static var playbackFailed: String { tr("Playback failed") }
        static var noPlaylist: String { tr("No playlist configured") }
        static var noPlaylistDescription: String { tr("Add a playlist URL in Settings to get started.") }
        static var invalidURL: String { tr("Invalid URL") }
        static var networkError: String { tr("Network error") }
        static var tryAgain: String { tr("Try Again") }
    }
    
    // MARK: - Actions
    enum Actions {
        static var ok: String { tr("OK") }
        static var cancel: String { tr("Cancel") }
        static var done: String { tr("Done") }
        static var save: String { tr("Save") }
        static var delete: String { tr("Delete") }
        static var confirm: String { tr("Confirm") }
        static var search: String { tr("Search") }
    }
}
