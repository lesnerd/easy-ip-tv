import Foundation

/// Represents a TV show/series
struct Show: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let posterURL: URL?
    let category: String
    let year: Int?
    let description: String?
    let rating: Double?
    let cast: String?
    let director: String?
    let genre: String?
    
    /// Seasons of the show
    var seasons: [Season]
    
    /// Whether this show is marked as a favorite
    var isFavorite: Bool = false
    
    init(
        id: String = UUID().uuidString,
        title: String,
        posterURL: URL? = nil,
        category: String,
        year: Int? = nil,
        description: String? = nil,
        rating: Double? = nil,
        cast: String? = nil,
        director: String? = nil,
        genre: String? = nil,
        seasons: [Season] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.posterURL = posterURL
        self.category = category
        self.year = year
        self.description = description
        self.rating = rating
        self.cast = cast
        self.director = director
        self.genre = genre
        self.seasons = seasons
        self.isFavorite = isFavorite
    }
    
    /// Total number of episodes across all seasons
    var totalEpisodes: Int {
        seasons.reduce(0) { $0 + $1.episodes.count }
    }
    
    /// Next unwatched episode
    var nextUnwatchedEpisode: Episode? {
        for season in seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber }) {
            if let episode = season.episodes.first(where: { $0.watchProgress < 0.9 }) {
                return episode
            }
        }
        return nil
    }
}

/// Represents a season of a TV show
struct Season: Identifiable, Codable, Hashable {
    let id: String
    let seasonNumber: Int
    let title: String?
    let posterURL: URL?
    
    /// Episodes in this season
    var episodes: [Episode]
    
    init(
        id: String = UUID().uuidString,
        seasonNumber: Int,
        title: String? = nil,
        posterURL: URL? = nil,
        episodes: [Episode] = []
    ) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.title = title
        self.posterURL = posterURL
        self.episodes = episodes
    }
    
    /// Display title for the season
    var displayTitle: String {
        title ?? String(localized: "Season \(seasonNumber)")
    }
}

/// Represents an episode of a TV show
struct Episode: Identifiable, Codable, Hashable {
    let id: String
    let episodeNumber: Int
    let title: String
    let thumbnailURL: URL?
    let streamURL: URL
    let duration: Int? // in minutes
    let description: String?
    
    /// Watch progress (0.0 to 1.0)
    var watchProgress: Double = 0.0
    
    init(
        id: String = UUID().uuidString,
        episodeNumber: Int,
        title: String,
        thumbnailURL: URL? = nil,
        streamURL: URL,
        duration: Int? = nil,
        description: String? = nil,
        watchProgress: Double = 0.0
    ) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.streamURL = streamURL
        self.duration = duration
        self.description = description
        self.watchProgress = watchProgress
    }
    
    /// Creates an Episode from an M3UItem
    static func from(_ item: M3UItem, episodeNumber: Int) -> Episode {
        Episode(
            id: item.id,
            episodeNumber: episodeNumber,
            title: item.name,
            thumbnailURL: item.logoURL,
            streamURL: item.streamURL,
            duration: item.duration > 0 ? item.duration / 60 : nil
        )
    }
    
    /// Display title including episode number
    var displayTitle: String {
        String(localized: "E\(episodeNumber): \(title)")
    }
}

// MARK: - Show List Helpers
extension Array where Element == Show {
    /// Groups shows by their category
    var groupedByCategory: [String: [Show]] {
        Dictionary(grouping: self) { $0.category }
    }
    
    /// Returns only favorited shows
    var favorites: [Show] {
        filter { $0.isFavorite }
    }
    
    /// Returns shows sorted alphabetically by title
    var sortedByTitle: [Show] {
        sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
