import Foundation

/// Service for local storage of favorites, preferences, and watch history
@MainActor
class StorageService: ObservableObject {
    
    static let shared = StorageService()
    
    // MARK: - Keys
    
    private enum Keys {
        static let favorites = "user_favorites"
        static let favoriteChannelIds = "favorite_channel_ids"
        static let favoriteMovieIds = "favorite_movie_ids"
        static let favoriteShowIds = "favorite_show_ids"
        static let watchProgress = "watch_progress"
        static let lastWatchedChannel = "last_watched_channel"
        static let playlistURLs = "playlist_urls"
        static let selectedLanguage = "selected_language"
    }
    
    // MARK: - Properties
    
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    @Published private(set) var favoriteChannelIds: Set<String> = []
    @Published private(set) var favoriteMovieIds: Set<String> = []
    @Published private(set) var favoriteShowIds: Set<String> = []
    @Published private(set) var playlistURLs: [URL] = []
    
    // MARK: - Initialization
    
    private init() {
        loadData()
    }
    
    private func loadData() {
        // Load favorite IDs
        if let data = defaults.data(forKey: Keys.favoriteChannelIds),
           let ids = try? decoder.decode(Set<String>.self, from: data) {
            favoriteChannelIds = ids
        }
        
        if let data = defaults.data(forKey: Keys.favoriteMovieIds),
           let ids = try? decoder.decode(Set<String>.self, from: data) {
            favoriteMovieIds = ids
        }
        
        if let data = defaults.data(forKey: Keys.favoriteShowIds),
           let ids = try? decoder.decode(Set<String>.self, from: data) {
            favoriteShowIds = ids
        }
        
        // Load playlist URLs
        if let data = defaults.data(forKey: Keys.playlistURLs),
           let urls = try? decoder.decode([URL].self, from: data) {
            playlistURLs = urls
        }
    }
    
    // MARK: - Favorites Management
    
    /// Toggles favorite status for a channel
    func toggleFavorite(channelId: String) {
        if favoriteChannelIds.contains(channelId) {
            favoriteChannelIds.remove(channelId)
        } else {
            favoriteChannelIds.insert(channelId)
        }
        saveFavoriteChannelIds()
    }
    
    /// Toggles favorite status for a movie
    func toggleFavorite(movieId: String) {
        if favoriteMovieIds.contains(movieId) {
            favoriteMovieIds.remove(movieId)
        } else {
            favoriteMovieIds.insert(movieId)
        }
        saveFavoriteMovieIds()
    }
    
    /// Toggles favorite status for a show
    func toggleFavorite(showId: String) {
        if favoriteShowIds.contains(showId) {
            favoriteShowIds.remove(showId)
        } else {
            favoriteShowIds.insert(showId)
        }
        saveFavoriteShowIds()
    }
    
    /// Checks if a channel is favorited
    func isFavorite(channelId: String) -> Bool {
        favoriteChannelIds.contains(channelId)
    }
    
    /// Checks if a movie is favorited
    func isFavorite(movieId: String) -> Bool {
        favoriteMovieIds.contains(movieId)
    }
    
    /// Checks if a show is favorited
    func isFavorite(showId: String) -> Bool {
        favoriteShowIds.contains(showId)
    }
    
    private func saveFavoriteChannelIds() {
        if let data = try? encoder.encode(favoriteChannelIds) {
            defaults.set(data, forKey: Keys.favoriteChannelIds)
        }
    }
    
    private func saveFavoriteMovieIds() {
        if let data = try? encoder.encode(favoriteMovieIds) {
            defaults.set(data, forKey: Keys.favoriteMovieIds)
        }
    }
    
    private func saveFavoriteShowIds() {
        if let data = try? encoder.encode(favoriteShowIds) {
            defaults.set(data, forKey: Keys.favoriteShowIds)
        }
    }
    
    // MARK: - Watch Progress
    
    /// Saves watch progress for a content item
    func saveWatchProgress(contentId: String, progress: Double) {
        var allProgress = getWatchProgress()
        allProgress[contentId] = progress
        
        if let data = try? encoder.encode(allProgress) {
            defaults.set(data, forKey: Keys.watchProgress)
        }
    }
    
    /// Gets watch progress for a content item
    func getWatchProgress(for contentId: String) -> Double {
        let allProgress = getWatchProgress()
        return allProgress[contentId] ?? 0.0
    }
    
    private func getWatchProgress() -> [String: Double] {
        guard let data = defaults.data(forKey: Keys.watchProgress),
              let progress = try? decoder.decode([String: Double].self, from: data) else {
            return [:]
        }
        return progress
    }
    
    // MARK: - Last Watched Channel
    
    /// Saves the last watched channel ID
    func saveLastWatchedChannel(id: String) {
        defaults.set(id, forKey: Keys.lastWatchedChannel)
    }
    
    /// Gets the last watched channel ID
    func getLastWatchedChannelId() -> String? {
        defaults.string(forKey: Keys.lastWatchedChannel)
    }
    
    // MARK: - Playlist Management
    
    /// Adds a playlist URL
    func addPlaylist(url: URL) {
        if !playlistURLs.contains(url) {
            playlistURLs.append(url)
            savePlaylistURLs()
        }
    }
    
    /// Removes a playlist URL
    func removePlaylist(url: URL) {
        playlistURLs.removeAll { $0 == url }
        savePlaylistURLs()
    }
    
    /// Removes a playlist at index
    func removePlaylist(at index: Int) {
        guard index >= 0 && index < playlistURLs.count else { return }
        playlistURLs.remove(at: index)
        savePlaylistURLs()
    }
    
    private func savePlaylistURLs() {
        if let data = try? encoder.encode(playlistURLs) {
            defaults.set(data, forKey: Keys.playlistURLs)
        }
    }
    
    // MARK: - Language
    
    /// Saves the selected language
    func saveSelectedLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Keys.selectedLanguage)
    }
    
    /// Gets the selected language
    func getSelectedLanguage() -> AppLanguage {
        guard let rawValue = defaults.string(forKey: Keys.selectedLanguage),
              let language = AppLanguage(rawValue: rawValue) else {
            return .english
        }
        return language
    }
    
    // MARK: - Clear Data
    
    /// Clears all stored data
    func clearAllData() {
        favoriteChannelIds.removeAll()
        favoriteMovieIds.removeAll()
        favoriteShowIds.removeAll()
        playlistURLs.removeAll()
        
        defaults.removeObject(forKey: Keys.favoriteChannelIds)
        defaults.removeObject(forKey: Keys.favoriteMovieIds)
        defaults.removeObject(forKey: Keys.favoriteShowIds)
        defaults.removeObject(forKey: Keys.watchProgress)
        defaults.removeObject(forKey: Keys.lastWatchedChannel)
        defaults.removeObject(forKey: Keys.playlistURLs)
    }
}
