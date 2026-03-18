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
        static let favoriteChannels = "favorite_channels"
        static let favoriteMovies = "favorite_movies"
        static let favoriteShows = "favorite_shows"
        static let watchProgress = "watch_progress"
        static let lastWatchedChannel = "last_watched_channel"
        static let playlistURLs = "playlist_urls"
        static let selectedLanguage = "selected_language"
        static let streamQuality = "stream_quality"
        static let subtitleLanguage = "subtitle_language"
        static let autoPlayNextEpisode = "auto_play_next_episode"
        static let languagePriorityConfig = "language_priority_config"
        static let recentlyWatched = "recently_watched"
        static let continueWatching = "continue_watching"
        static let cachedChannels = "cached_channels"
        static let cachedMovies = "cached_movies"
        static let cachedShows = "cached_shows"
        static let cachedCategories = "cached_categories"
        static let cacheTimestamp = "cache_timestamp"
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
    
    /// Adds multiple channels to favorites
    func addFavorites(channelIds: [String]) {
        for id in channelIds {
            favoriteChannelIds.insert(id)
        }
        saveFavoriteChannelIds()
    }
    
    /// Removes multiple channels from favorites
    func removeFavorites(channelIds: [String]) {
        for id in channelIds {
            favoriteChannelIds.remove(id)
        }
        saveFavoriteChannelIds()
    }
    
    /// Checks if all given channel IDs are favorites
    func areAllFavorites(channelIds: [String]) -> Bool {
        guard !channelIds.isEmpty else { return false }
        return channelIds.allSatisfy { favoriteChannelIds.contains($0) }
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
    
    // MARK: - Favorite Items Storage (full objects)
    
    /// Saves a channel to favorites with full data
    func saveFavoriteChannel(_ channel: Channel) {
        var channels = getFavoriteChannels()
        if !channels.contains(where: { $0.id == channel.id }) {
            var favoriteChannel = channel
            favoriteChannel.isFavorite = true
            channels.append(favoriteChannel)
            saveFavoriteChannels(channels)
            #if DEBUG
            print("[Storage] Saved channel to favorites: \(channel.name), total: \(channels.count)")
            #endif
        }
    }
    
    /// Removes a channel from saved favorites
    func removeFavoriteChannel(id: String) {
        var channels = getFavoriteChannels()
        channels.removeAll { $0.id == id }
        saveFavoriteChannels(channels)
    }
    
    /// Gets all saved favorite channels
    func getFavoriteChannels() -> [Channel] {
        guard let data = defaults.data(forKey: Keys.favoriteChannels) else {
            #if DEBUG
            print("[Storage] No favorite channels data found")
            #endif
            return []
        }
        guard let channels = try? decoder.decode([Channel].self, from: data) else {
            #if DEBUG
            print("[Storage] Failed to decode favorite channels")
            #endif
            return []
        }
        #if DEBUG
        print("[Storage] Loaded \(channels.count) favorite channels")
        #endif
        return channels
    }
    
    private func saveFavoriteChannels(_ channels: [Channel]) {
        do {
            let data = try encoder.encode(channels)
            defaults.set(data, forKey: Keys.favoriteChannels)
            defaults.synchronize()
            #if DEBUG
            print("[Storage] Successfully saved \(channels.count) favorite channels")
            #endif
        } catch {
            #if DEBUG
            print("[Storage] ERROR saving favorite channels: \(error)")
            #endif
        }
    }
    
    /// Saves a movie to favorites with full data
    func saveFavoriteMovie(_ movie: Movie) {
        var movies = getFavoriteMovies()
        if !movies.contains(where: { $0.id == movie.id }) {
            var favoriteMovie = movie
            favoriteMovie.isFavorite = true
            movies.append(favoriteMovie)
            saveFavoriteMovies(movies)
        }
    }
    
    /// Removes a movie from saved favorites
    func removeFavoriteMovie(id: String) {
        var movies = getFavoriteMovies()
        movies.removeAll { $0.id == id }
        saveFavoriteMovies(movies)
    }
    
    /// Gets all saved favorite movies
    func getFavoriteMovies() -> [Movie] {
        guard let data = defaults.data(forKey: Keys.favoriteMovies),
              let movies = try? decoder.decode([Movie].self, from: data) else {
            return []
        }
        return movies
    }
    
    private func saveFavoriteMovies(_ movies: [Movie]) {
        do {
            let data = try encoder.encode(movies)
            defaults.set(data, forKey: Keys.favoriteMovies)
            defaults.synchronize()
            #if DEBUG
            print("[Storage] Successfully saved \(movies.count) favorite movies")
            #endif
        } catch {
            #if DEBUG
            print("[Storage] ERROR saving favorite movies: \(error)")
            #endif
        }
    }
    
    /// Saves a show to favorites with full data
    func saveFavoriteShow(_ show: Show) {
        var shows = getFavoriteShows()
        if !shows.contains(where: { $0.id == show.id }) {
            var favoriteShow = show
            favoriteShow.isFavorite = true
            shows.append(favoriteShow)
            saveFavoriteShows(shows)
        }
    }
    
    /// Removes a show from saved favorites
    func removeFavoriteShow(id: String) {
        var shows = getFavoriteShows()
        shows.removeAll { $0.id == id }
        saveFavoriteShows(shows)
    }
    
    /// Gets all saved favorite shows
    func getFavoriteShows() -> [Show] {
        guard let data = defaults.data(forKey: Keys.favoriteShows),
              let shows = try? decoder.decode([Show].self, from: data) else {
            return []
        }
        return shows
    }
    
    private func saveFavoriteShows(_ shows: [Show]) {
        do {
            let data = try encoder.encode(shows)
            defaults.set(data, forKey: Keys.favoriteShows)
            defaults.synchronize()
            #if DEBUG
            print("[Storage] Successfully saved \(shows.count) favorite shows")
            #endif
        } catch {
            #if DEBUG
            print("[Storage] ERROR saving favorite shows: \(error)")
            #endif
        }
    }
    
    /// Saves multiple channels to favorites
    func saveFavoriteChannels(channels: [Channel]) {
        var existing = getFavoriteChannels()
        for channel in channels {
            if !existing.contains(where: { $0.id == channel.id }) {
                var favoriteChannel = channel
                favoriteChannel.isFavorite = true
                existing.append(favoriteChannel)
            }
        }
        saveFavoriteChannels(existing)
    }
    
    /// Removes multiple channels from saved favorites
    func removeFavoriteChannels(ids: [String]) {
        let idSet = Set(ids)
        var channels = getFavoriteChannels()
        channels.removeAll { idSet.contains($0.id) }
        saveFavoriteChannels(channels)
    }
    
    // MARK: - Watch Progress
    
    /// Saves watch progress for a content item
    func saveWatchProgress(contentId: String, progress: Double) {
        var allProgress = getWatchProgress()
        allProgress[contentId] = progress
        
        if let data = try? encoder.encode(allProgress) {
            defaults.set(data, forKey: Keys.watchProgress)
            defaults.synchronize()
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
    
    // MARK: - Playlist Type Detection
    
    /// Types of IPTV playlist sources
    enum PlaylistType: Equatable {
        case m3u
        case xtreamCodes
        case stalkerPortal
    }
    
    /// Detects the playlist type from a URL
    static func playlistType(for url: URL) -> PlaylistType {
        if StalkerPortalService.isStalkerPortalURL(url) {
            return .stalkerPortal
        } else if XtreamCodesService.isXtreamCodesURL(url) {
            return .xtreamCodes
        } else {
            return .m3u
        }
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
            defaults.synchronize()
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
    
    // MARK: - Stream Quality
    
    /// Saves the stream quality setting
    func saveStreamQuality(_ quality: String) {
        defaults.set(quality, forKey: Keys.streamQuality)
    }
    
    /// Gets the saved stream quality
    func getStreamQuality() -> String {
        defaults.string(forKey: Keys.streamQuality) ?? "Auto"
    }
    
    // MARK: - Subtitle Language
    
    /// Saves the preferred subtitle language
    func saveSubtitleLanguage(_ language: String?) {
        if let language = language {
            defaults.set(language, forKey: Keys.subtitleLanguage)
        } else {
            defaults.removeObject(forKey: Keys.subtitleLanguage)
        }
    }
    
    /// Gets the preferred subtitle language (nil means Off)
    func getSubtitleLanguage() -> String? {
        defaults.string(forKey: Keys.subtitleLanguage)
    }
    
    // MARK: - Language Priority
    
    /// Saves the language priority configuration
    func saveLanguagePriority(_ config: LanguagePriorityConfig) {
        if let data = try? encoder.encode(config) {
            defaults.set(data, forKey: Keys.languagePriorityConfig)
        }
    }
    
    /// Gets the language priority configuration
    func getLanguagePriority() -> LanguagePriorityConfig {
        guard let data = defaults.data(forKey: Keys.languagePriorityConfig),
              let config = try? decoder.decode(LanguagePriorityConfig.self, from: data) else {
            return .empty
        }
        return config
    }
    
    // MARK: - Auto-Play Settings
    
    /// Saves auto-play next episode preference
    func saveAutoPlayNextEpisode(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.autoPlayNextEpisode)
    }
    
    /// Gets auto-play next episode preference
    func getAutoPlayNextEpisode() -> Bool {
        defaults.bool(forKey: Keys.autoPlayNextEpisode)
    }
    
    // MARK: - Recently Watched
    
    /// Content item for recently watched tracking
    struct WatchedItem: Codable, Identifiable {
        let id: String
        let contentType: String // "channel", "movie", "show"
        let title: String
        let watchedDate: Date
        let imageURL: URL?
        let showId: String? // For episodes
        let seasonNumber: Int? // For episodes
        let episodeNumber: Int? // For episodes
        
        // Migration from old format
        private enum CodingKeys: String, CodingKey {
            case id, contentType, title, watchedDate, imageURL, showId, seasonNumber, episodeNumber
            case timestamp // Old key for migration (decode only)
        }
        
        init(id: String, contentType: String, title: String, watchedDate: Date, imageURL: URL? = nil, showId: String? = nil, seasonNumber: Int? = nil, episodeNumber: Int? = nil) {
            self.id = id
            self.contentType = contentType
            self.title = title
            self.watchedDate = watchedDate
            self.imageURL = imageURL
            self.showId = showId
            self.seasonNumber = seasonNumber
            self.episodeNumber = episodeNumber
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            contentType = try container.decode(String.self, forKey: .contentType)
            title = try container.decode(String.self, forKey: .title)
            imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
            showId = try container.decodeIfPresent(String.self, forKey: .showId)
            seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber)
            episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
            
            // Try new key first, fall back to old key for migration
            if let date = try? container.decode(Date.self, forKey: .watchedDate) {
                watchedDate = date
            } else {
                watchedDate = try container.decode(Date.self, forKey: .timestamp)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(contentType, forKey: .contentType)
            try container.encode(title, forKey: .title)
            try container.encode(watchedDate, forKey: .watchedDate)
            try container.encodeIfPresent(imageURL, forKey: .imageURL)
            try container.encodeIfPresent(showId, forKey: .showId)
            try container.encodeIfPresent(seasonNumber, forKey: .seasonNumber)
            try container.encodeIfPresent(episodeNumber, forKey: .episodeNumber)
        }
    }
    
    /// Saves a recently watched item
    func saveRecentlyWatched(item: WatchedItem) {
        var items = getRecentlyWatched()
        
        // Remove existing item with same ID
        items.removeAll { $0.id == item.id }
        
        // Add new item at the beginning
        items.insert(item, at: 0)
        
        // Keep only last 20 items
        if items.count > 20 {
            items = Array(items.prefix(20))
        }
        
        if let data = try? encoder.encode(items) {
            defaults.set(data, forKey: Keys.recentlyWatched)
            defaults.synchronize()
        }
    }
    
    /// Gets recently watched items
    func getRecentlyWatched() -> [WatchedItem] {
        guard let data = defaults.data(forKey: Keys.recentlyWatched),
              let items = try? decoder.decode([WatchedItem].self, from: data) else {
            return []
        }
        return items
    }
    
    // MARK: - Continue Watching
    
    /// Content item for continue watching
    struct ContinueWatchingItem: Codable, Identifiable {
        let id: String // contentId
        let contentType: String // "movie" or "show"
        let title: String
        let progress: Double // 0.0 to 1.0
        let currentTime: Double // seconds
        let duration: Double // seconds
        let timestamp: Date
        let showId: String? // For shows
        let episodeId: String? // For shows
        let seasonNumber: Int? // For shows
        let episodeNumber: Int? // For shows
        let episodeTitle: String? // For shows
        let posterURL: URL? // Poster/thumbnail for display
        let showTitle: String? // Parent show title for episodes
        let snapshotURL: URL? // Local file URL of captured video frame
        
        private enum CodingKeys: String, CodingKey {
            case id, contentType, title, progress, currentTime, duration, timestamp
            case showId, episodeId, seasonNumber, episodeNumber, episodeTitle
            case posterURL, showTitle, snapshotURL
        }
        
        init(id: String, contentType: String, title: String, progress: Double,
             currentTime: Double, duration: Double, timestamp: Date,
             showId: String?, episodeId: String?, seasonNumber: Int?,
             episodeNumber: Int?, episodeTitle: String?,
             posterURL: URL? = nil, showTitle: String? = nil,
             snapshotURL: URL? = nil) {
            self.id = id
            self.contentType = contentType
            self.title = title
            self.progress = progress
            self.currentTime = currentTime
            self.duration = duration
            self.timestamp = timestamp
            self.showId = showId
            self.episodeId = episodeId
            self.seasonNumber = seasonNumber
            self.episodeNumber = episodeNumber
            self.episodeTitle = episodeTitle
            self.posterURL = posterURL
            self.showTitle = showTitle
            self.snapshotURL = snapshotURL
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            contentType = try container.decode(String.self, forKey: .contentType)
            title = try container.decode(String.self, forKey: .title)
            progress = try container.decode(Double.self, forKey: .progress)
            currentTime = try container.decode(Double.self, forKey: .currentTime)
            duration = try container.decode(Double.self, forKey: .duration)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            showId = try container.decodeIfPresent(String.self, forKey: .showId)
            episodeId = try container.decodeIfPresent(String.self, forKey: .episodeId)
            seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber)
            episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
            episodeTitle = try container.decodeIfPresent(String.self, forKey: .episodeTitle)
            posterURL = try container.decodeIfPresent(URL.self, forKey: .posterURL)
            showTitle = try container.decodeIfPresent(String.self, forKey: .showTitle)
            snapshotURL = try container.decodeIfPresent(URL.self, forKey: .snapshotURL)
        }
    }
    
    /// Saves a continue watching item. Items watched past 90% are considered finished and removed.
    func saveContinueWatching(item: ContinueWatchingItem, nextEpisode: (episode: Episode, seasonNumber: Int)? = nil) {
        var items = getContinueWatching()
        
        // Remove existing item with same ID
        items.removeAll { $0.id == item.id }
        // Also remove any existing entry for the same show (avoid duplicates per show)
        if item.contentType == "show", let showId = item.showId {
            items.removeAll { $0.showId == showId }
        }
        
        if item.progress >= 0.9 {
            // Nearly finished — treat as complete, don't re-add
        } else if item.progress > 0.05 {
            items.insert(item, at: 0)
        }
        
        if items.count > 50 {
            items = Array(items.prefix(50))
        }
        
        if let data = try? encoder.encode(items) {
            defaults.set(data, forKey: Keys.continueWatching)
            defaults.synchronize()
        }
    }
    
    /// Gets continue watching items
    func getContinueWatching() -> [ContinueWatchingItem] {
        guard let data = defaults.data(forKey: Keys.continueWatching),
              let items = try? decoder.decode([ContinueWatchingItem].self, from: data) else {
            return []
        }
        return items
    }
    
    /// Removes a continue watching item (when finished)
    func removeContinueWatching(id: String) {
        var items = getContinueWatching()
        items.removeAll { $0.id == id }
        
        if let data = try? encoder.encode(items) {
            defaults.set(data, forKey: Keys.continueWatching)
            defaults.synchronize()
        }
    }
    
    // MARK: - Content Cache (Categories Only - Lightweight)
    // NOTE: Full content caching removed to prevent UserDefaults size limit crashes
    // with large IPTV providers (200K+ items). Categories are small and safe to cache.
    
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
        defaults.removeObject(forKey: Keys.streamQuality)
        defaults.removeObject(forKey: Keys.subtitleLanguage)
        defaults.removeObject(forKey: Keys.autoPlayNextEpisode)
        defaults.removeObject(forKey: Keys.recentlyWatched)
        defaults.removeObject(forKey: Keys.continueWatching)
        defaults.removeObject(forKey: Keys.cachedChannels)
    }
}
