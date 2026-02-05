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
    
    /// Toggles favorite for a channel
    func toggleFavorite(channel: Channel) {
        storage.toggleFavorite(channelId: channel.id)
        if isFavorite(channel: channel) {
            if !favoriteChannels.contains(where: { $0.id == channel.id }) {
                var updatedChannel = channel
                updatedChannel.isFavorite = true
                favoriteChannels.append(updatedChannel)
            }
        } else {
            favoriteChannels.removeAll { $0.id == channel.id }
        }
    }
    
    /// Toggles favorite for a movie
    func toggleFavorite(movie: Movie) {
        storage.toggleFavorite(movieId: movie.id)
        if isFavorite(movie: movie) {
            if !favoriteMovies.contains(where: { $0.id == movie.id }) {
                var updatedMovie = movie
                updatedMovie.isFavorite = true
                favoriteMovies.append(updatedMovie)
            }
        } else {
            favoriteMovies.removeAll { $0.id == movie.id }
        }
    }
    
    /// Toggles favorite for a show
    func toggleFavorite(show: Show) {
        storage.toggleFavorite(showId: show.id)
        if isFavorite(show: show) {
            if !favoriteShows.contains(where: { $0.id == show.id }) {
                var updatedShow = show
                updatedShow.isFavorite = true
                favoriteShows.append(updatedShow)
            }
        } else {
            favoriteShows.removeAll { $0.id == show.id }
        }
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
