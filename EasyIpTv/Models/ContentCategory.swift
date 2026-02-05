import Foundation

/// Represents a category of content (e.g., "Sports", "News", "Hungarian Channels")
struct ContentCategory: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let contentType: ContentType
    let itemCount: Int
    let thumbnailURL: URL?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        contentType: ContentType,
        itemCount: Int = 0,
        thumbnailURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.contentType = contentType
        self.itemCount = itemCount
        self.thumbnailURL = thumbnailURL
    }
}

/// Represents a favoritable item (used for storing favorites)
enum FavoriteItem: Codable, Hashable, Identifiable {
    case channel(Channel)
    case movie(Movie)
    case show(Show)
    
    var id: String {
        switch self {
        case .channel(let channel): return "channel_\(channel.id)"
        case .movie(let movie): return "movie_\(movie.id)"
        case .show(let show): return "show_\(show.id)"
        }
    }
    
    var name: String {
        switch self {
        case .channel(let channel): return channel.name
        case .movie(let movie): return movie.title
        case .show(let show): return show.title
        }
    }
    
    var category: String {
        switch self {
        case .channel(let channel): return channel.category
        case .movie(let movie): return movie.category
        case .show(let show): return show.category
        }
    }
    
    var contentType: ContentType {
        switch self {
        case .channel: return .liveTV
        case .movie: return .movie
        case .show: return .series
        }
    }
    
    var imageURL: URL? {
        switch self {
        case .channel(let channel): return channel.logoURL
        case .movie(let movie): return movie.posterURL
        case .show(let show): return show.posterURL
        }
    }
    
    var streamURL: URL? {
        switch self {
        case .channel(let channel): return channel.streamURL
        case .movie(let movie): return movie.streamURL
        case .show: return nil // Shows don't have a direct stream URL
        }
    }
}

/// Groups favorites by category for display
struct FavoriteGroup: Identifiable {
    let id: String
    let categoryName: String
    let contentType: ContentType
    var items: [FavoriteItem]
    
    init(categoryName: String, contentType: ContentType, items: [FavoriteItem] = []) {
        self.id = "\(contentType.rawValue)_\(categoryName)"
        self.categoryName = categoryName
        self.contentType = contentType
        self.items = items
    }
}
