import Foundation

/// Represents a movie in the VOD catalog
struct Movie: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let posterURL: URL?
    let streamURL: URL
    let category: String
    let year: Int?
    let duration: Int? // in minutes
    let description: String?
    let rating: Double?
    
    /// Whether this movie is marked as a favorite
    var isFavorite: Bool = false
    
    /// Watch progress (0.0 to 1.0)
    var watchProgress: Double = 0.0
    
    init(
        id: String = UUID().uuidString,
        title: String,
        posterURL: URL? = nil,
        streamURL: URL,
        category: String,
        year: Int? = nil,
        duration: Int? = nil,
        description: String? = nil,
        rating: Double? = nil,
        isFavorite: Bool = false,
        watchProgress: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.posterURL = posterURL
        self.streamURL = streamURL
        self.category = category
        self.year = year
        self.duration = duration
        self.description = description
        self.rating = rating
        self.isFavorite = isFavorite
        self.watchProgress = watchProgress
    }
    
    /// Creates a Movie from an M3UItem
    static func from(_ item: M3UItem) -> Movie {
        // Try to parse year from title (e.g., "Movie Name (2023)")
        var year: Int? = nil
        var cleanTitle = item.name
        
        if let match = item.name.range(of: #"\((\d{4})\)"#, options: .regularExpression) {
            let yearString = String(item.name[match]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            year = Int(yearString)
            cleanTitle = item.name.replacingCharacters(in: match, with: "").trimmingCharacters(in: .whitespaces)
        }
        
        return Movie(
            id: item.id,
            title: cleanTitle,
            posterURL: item.logoURL,
            streamURL: item.streamURL,
            category: item.groupTitle,
            year: year,
            duration: item.duration > 0 ? item.duration / 60 : nil
        )
    }
}

// MARK: - Movie List Helpers
extension Array where Element == Movie {
    /// Groups movies by their category
    var groupedByCategory: [String: [Movie]] {
        Dictionary(grouping: self) { $0.category }
    }
    
    /// Returns only favorited movies
    var favorites: [Movie] {
        filter { $0.isFavorite }
    }
    
    /// Returns movies sorted alphabetically by title
    var sortedByTitle: [Movie] {
        sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    /// Returns movies sorted by year (newest first)
    var sortedByYear: [Movie] {
        sorted { ($0.year ?? 0) > ($1.year ?? 0) }
    }
}
