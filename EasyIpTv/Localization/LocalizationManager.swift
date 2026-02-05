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
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            StorageService.shared.saveSelectedLanguage(currentLanguage)
            updateBundle()
        }
    }
    
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
        } else {
            self.bundle = .main
        }
    }
}

// MARK: - Localized Strings

/// Namespace for localized strings used throughout the app
enum L10n {
    
    // MARK: - Navigation
    enum Navigation {
        static var home: String { String(localized: "Home") }
        static var favorites: String { String(localized: "Favorites") }
        static var liveTV: String { String(localized: "Live TV") }
        static var movies: String { String(localized: "Movies") }
        static var shows: String { String(localized: "Shows") }
        static var settings: String { String(localized: "Settings") }
    }
    
    // MARK: - Player
    enum Player {
        static var play: String { String(localized: "Play") }
        static var pause: String { String(localized: "Pause") }
        static var stop: String { String(localized: "Stop") }
        static var channelUp: String { String(localized: "Channel Up") }
        static var channelDown: String { String(localized: "Channel Down") }
        static var nowPlaying: String { String(localized: "Now Playing") }
        static var loading: String { String(localized: "Loading...") }
        static var buffering: String { String(localized: "Buffering...") }
    }
    
    // MARK: - Favorites
    enum Favorites {
        static var addToFavorites: String { String(localized: "Add to Favorites") }
        static var removeFromFavorites: String { String(localized: "Remove from Favorites") }
        static var noFavorites: String { String(localized: "No favorites yet") }
        static var noFavoritesDescription: String { String(localized: "Long press on any channel, movie, or show to add it to your favorites.") }
    }
    
    // MARK: - Settings
    enum Settings {
        static var language: String { String(localized: "Language") }
        static var playlists: String { String(localized: "Playlists") }
        static var addPlaylist: String { String(localized: "Add Playlist") }
        static var removePlaylist: String { String(localized: "Remove Playlist") }
        static var enterPlaylistURL: String { String(localized: "Enter playlist URL") }
        static var quality: String { String(localized: "Quality") }
        static var about: String { String(localized: "About") }
        static var version: String { String(localized: "Version") }
        static var clearData: String { String(localized: "Clear All Data") }
        static var clearDataConfirmation: String { String(localized: "Are you sure you want to clear all data? This action cannot be undone.") }
    }
    
    // MARK: - Content
    enum Content {
        static var allChannels: String { String(localized: "All Channels") }
        static var allMovies: String { String(localized: "All Movies") }
        static var allShows: String { String(localized: "All Shows") }
        static var categories: String { String(localized: "Categories") }
        static var recentlyWatched: String { String(localized: "Recently Watched") }
        static var continueWatching: String { String(localized: "Continue Watching") }
        static func season(_ number: Int) -> String { String(localized: "Season \(number)") }
        static func episode(_ number: Int) -> String { String(localized: "Episode \(number)") }
    }
    
    // MARK: - Errors
    enum Errors {
        static var loadingFailed: String { String(localized: "Failed to load content") }
        static var playbackFailed: String { String(localized: "Playback failed") }
        static var noPlaylist: String { String(localized: "No playlist configured") }
        static var noPlaylistDescription: String { String(localized: "Add a playlist URL in Settings to get started.") }
        static var invalidURL: String { String(localized: "Invalid URL") }
        static var networkError: String { String(localized: "Network error") }
        static var tryAgain: String { String(localized: "Try Again") }
    }
    
    // MARK: - Actions
    enum Actions {
        static var ok: String { String(localized: "OK") }
        static var cancel: String { String(localized: "Cancel") }
        static var done: String { String(localized: "Done") }
        static var save: String { String(localized: "Save") }
        static var delete: String { String(localized: "Delete") }
        static var confirm: String { String(localized: "Confirm") }
        static var search: String { String(localized: "Search") }
    }
}
