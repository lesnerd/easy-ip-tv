import Foundation
import SwiftUI

/// ViewModel for managing favorites
@MainActor
class FavoritesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var favoriteChannels: [Channel] = []
    @Published var favoriteMovies: [Movie] = []
    @Published var favoriteShows: [Show] = []
    
    // MARK: - Private Properties
    
    private let storage = StorageService.shared
    
    // MARK: - Initialization
    
    init() {
        loadSavedFavorites()
    }
    
    /// Load saved favorites from storage
    func loadSavedFavorites() {
        let channels = storage.getFavoriteChannels()
        let movies = storage.getFavoriteMovies()
        let shows = storage.getFavoriteShows()
        
        print("[FavoritesVM] Loading saved favorites: \(channels.count) channels, \(movies.count) movies, \(shows.count) shows")
        
        // Use saved full data if available
        if !channels.isEmpty {
            favoriteChannels = channels
        }
        if !movies.isEmpty {
            favoriteMovies = movies
        }
        if !shows.isEmpty {
            favoriteShows = shows
        }
    }
    
    /// Sync favorites with content that was loaded from API
    /// This handles the case where favorite IDs exist but full data wasn't saved
    func syncFavorites(channels: [Channel], movies: [Movie], shows: [Show]) {
        // Get favorite IDs
        let channelIds = storage.favoriteChannelIds
        let movieIds = storage.favoriteMovieIds
        let showIds = storage.favoriteShowIds
        
        // If we have IDs but no saved data, populate from loaded content
        if !channelIds.isEmpty && favoriteChannels.isEmpty {
            let favorites = channels.filter { channelIds.contains($0.id) }
            if !favorites.isEmpty {
                favoriteChannels = favorites.map { channel in
                    var c = channel
                    c.isFavorite = true
                    return c
                }
                // Save the full data for next time
                storage.saveFavoriteChannels(channels: favoriteChannels)
                print("[FavoritesVM] Synced \(favoriteChannels.count) channels from content")
            }
        }
        
        if !movieIds.isEmpty && favoriteMovies.isEmpty {
            let favorites = movies.filter { movieIds.contains($0.id) }
            if !favorites.isEmpty {
                favoriteMovies = favorites.map { movie in
                    var m = movie
                    m.isFavorite = true
                    return m
                }
                // Save the full data for next time
                for movie in favoriteMovies {
                    storage.saveFavoriteMovie(movie)
                }
                print("[FavoritesVM] Synced \(favoriteMovies.count) movies from content")
            }
        }
        
        if !showIds.isEmpty && favoriteShows.isEmpty {
            let favorites = shows.filter { showIds.contains($0.id) }
            if !favorites.isEmpty {
                favoriteShows = favorites.map { show in
                    var s = show
                    s.isFavorite = true
                    return s
                }
                // Save the full data for next time
                for show in favoriteShows {
                    storage.saveFavoriteShow(show)
                }
                print("[FavoritesVM] Synced \(favoriteShows.count) shows from content")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether there are any favorites
    var hasFavorites: Bool {
        !favoriteChannels.isEmpty || !favoriteMovies.isEmpty || !favoriteShows.isEmpty
    }
    
    /// Total number of favorites
    var totalFavoritesCount: Int {
        favoriteChannels.count + favoriteMovies.count + favoriteShows.count
    }
    
    /// Favorite channels grouped by category
    var favoriteChannelsByCategory: [String: [Channel]] {
        Dictionary(grouping: favoriteChannels) { $0.category }
    }
    
    /// Favorite movies grouped by category
    var favoriteMoviesByCategory: [String: [Movie]] {
        Dictionary(grouping: favoriteMovies) { $0.category }
    }
    
    /// Favorite shows grouped by category
    var favoriteShowsByCategory: [String: [Show]] {
        Dictionary(grouping: favoriteShows) { $0.category }
    }
    
    /// All favorite groups for display
    var favoriteGroups: [FavoriteGroup] {
        var groups: [FavoriteGroup] = []
        
        // Add channel groups
        for (category, channels) in favoriteChannelsByCategory {
            let items = channels.map { FavoriteItem.channel($0) }
            groups.append(FavoriteGroup(categoryName: category, contentType: .liveTV, items: items))
        }
        
        // Add movie groups
        for (category, movies) in favoriteMoviesByCategory {
            let items = movies.map { FavoriteItem.movie($0) }
            groups.append(FavoriteGroup(categoryName: category, contentType: .movie, items: items))
        }
        
        // Add show groups
        for (category, shows) in favoriteShowsByCategory {
            let items = shows.map { FavoriteItem.show($0) }
            groups.append(FavoriteGroup(categoryName: category, contentType: .series, items: items))
        }
        
        return groups.sorted { $0.categoryName < $1.categoryName }
    }
    
    // MARK: - Public Methods
    
    /// Updates favorites from content
    func updateFavorites(channels: [Channel], movies: [Movie], shows: [Show]) {
        favoriteChannels = channels.filter { storage.isFavorite(channelId: $0.id) }
        favoriteMovies = movies.filter { storage.isFavorite(movieId: $0.id) }
        favoriteShows = shows.filter { storage.isFavorite(showId: $0.id) }
    }
    
    /// Checks if a channel is favorited
    func isFavorite(channel: Channel) -> Bool {
        storage.isFavorite(channelId: channel.id)
    }
    
    /// Checks if a movie is favorited
    func isFavorite(movie: Movie) -> Bool {
        storage.isFavorite(movieId: movie.id)
    }
    
    /// Checks if a show is favorited
    func isFavorite(show: Show) -> Bool {
        storage.isFavorite(showId: show.id)
    }
    
    /// Toggles favorite for a channel (called AFTER contentViewModel.toggleFavorite)
    /// Note: storage.toggleFavorite is already called by contentViewModel, don't call it again
    func toggleFavorite(channel: Channel) {
        // Check new state (already toggled by contentViewModel)
        let isNowFavorite = isFavorite(channel: channel)
        print("[FavoritesVM] toggleFavorite channel: \(channel.name), isNowFavorite: \(isNowFavorite)")
        
        if isNowFavorite {
            // Add to favorites
            if !favoriteChannels.contains(where: { $0.id == channel.id }) {
                var updatedChannel = channel
                updatedChannel.isFavorite = true
                favoriteChannels.append(updatedChannel)
                print("[FavoritesVM] Added to array, count: \(favoriteChannels.count)")
            }
            storage.saveFavoriteChannel(channel)
        } else {
            // Remove from favorites
            favoriteChannels.removeAll { $0.id == channel.id }
            storage.removeFavoriteChannel(id: channel.id)
            print("[FavoritesVM] Removed from favorites")
        }
    }
    
    /// Toggles favorite for a movie (called AFTER contentViewModel.toggleFavorite)
    func toggleFavorite(movie: Movie) {
        // Check new state (already toggled by contentViewModel)
        let isNowFavorite = isFavorite(movie: movie)
        
        if isNowFavorite {
            // Add to favorites
            if !favoriteMovies.contains(where: { $0.id == movie.id }) {
                var updatedMovie = movie
                updatedMovie.isFavorite = true
                favoriteMovies.append(updatedMovie)
            }
            storage.saveFavoriteMovie(movie)
        } else {
            // Remove from favorites
            favoriteMovies.removeAll { $0.id == movie.id }
            storage.removeFavoriteMovie(id: movie.id)
        }
    }
    
    /// Toggles favorite for a show (called AFTER contentViewModel.toggleFavorite)
    func toggleFavorite(show: Show) {
        // Check new state (already toggled by contentViewModel)
        let isNowFavorite = isFavorite(show: show)
        
        if isNowFavorite {
            // Add to favorites
            if !favoriteShows.contains(where: { $0.id == show.id }) {
                var updatedShow = show
                updatedShow.isFavorite = true
                favoriteShows.append(updatedShow)
            }
            storage.saveFavoriteShow(show)
        } else {
            // Remove from favorites
            favoriteShows.removeAll { $0.id == show.id }
            storage.removeFavoriteShow(id: show.id)
        }
    }
    
    /// Adds multiple channels to favorites
    func addFavorites(channels: [Channel]) {
        let channelIds = channels.map { $0.id }
        storage.addFavorites(channelIds: channelIds)
        storage.saveFavoriteChannels(channels: channels)
        
        for channel in channels {
            if !favoriteChannels.contains(where: { $0.id == channel.id }) {
                var updatedChannel = channel
                updatedChannel.isFavorite = true
                favoriteChannels.append(updatedChannel)
            }
        }
    }
    
    /// Removes multiple channels from favorites
    func removeFavorites(channels: [Channel]) {
        let channelIds = Set(channels.map { $0.id })
        storage.removeFavorites(channelIds: Array(channelIds))
        storage.removeFavoriteChannels(ids: Array(channelIds))
        favoriteChannels.removeAll { channelIds.contains($0.id) }
    }
    
    /// Removes a favorite item
    func removeFavorite(_ item: FavoriteItem) {
        switch item {
        case .channel(let channel):
            toggleFavorite(channel: channel)
        case .movie(let movie):
            toggleFavorite(movie: movie)
        case .show(let show):
            toggleFavorite(show: show)
        }
    }
}
