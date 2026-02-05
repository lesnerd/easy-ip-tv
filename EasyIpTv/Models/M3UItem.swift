import Foundation

/// Represents a parsed item from an M3U playlist
struct M3UItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let logoURL: URL?
    let streamURL: URL
    let groupTitle: String
    let tvgId: String?
    let tvgName: String?
    let duration: Int
    
    /// Inferred content type based on group title patterns
    var inferredContentType: ContentType {
        let groupLower = groupTitle.lowercased()
        
        // Common patterns for movies
        if groupLower.contains("movie") || groupLower.contains("film") || groupLower.contains("vod") {
            return .movie
        }
        
        // Common patterns for series/shows
        if groupLower.contains("series") || groupLower.contains("show") || groupLower.contains("episode") {
            return .series
        }
        
        // Default to live TV
        return .liveTV
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        logoURL: URL? = nil,
        streamURL: URL,
        groupTitle: String,
        tvgId: String? = nil,
        tvgName: String? = nil,
        duration: Int = -1
    ) {
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.groupTitle = groupTitle
        self.tvgId = tvgId
        self.tvgName = tvgName
        self.duration = duration
    }
}
