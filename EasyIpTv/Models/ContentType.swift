import Foundation

/// Represents the type of content in the IPTV catalog
enum ContentType: String, Codable, CaseIterable {
    case liveTV = "live"
    case movie = "movie"
    case series = "series"
    
    /// Display name for the content type (localized)
    var displayName: String {
        switch self {
        case .liveTV:
            return String(localized: "Live TV")
        case .movie:
            return String(localized: "Movies")
        case .series:
            return String(localized: "Shows")
        }
    }
    
    /// System image name for the content type
    var iconName: String {
        switch self {
        case .liveTV:
            return "tv"
        case .movie:
            return "film"
        case .series:
            return "play.rectangle.on.rectangle"
        }
    }
}
