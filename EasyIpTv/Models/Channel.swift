import Foundation

/// Represents a live TV channel
struct Channel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let logoURL: URL?
    let streamURL: URL
    let category: String
    let channelNumber: Int?
    let tvgId: String?
    
    /// Whether this channel is marked as a favorite
    var isFavorite: Bool = false
    
    init(
        id: String = UUID().uuidString,
        name: String,
        logoURL: URL? = nil,
        streamURL: URL,
        category: String,
        channelNumber: Int? = nil,
        tvgId: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.category = category
        self.channelNumber = channelNumber
        self.tvgId = tvgId
        self.isFavorite = isFavorite
    }
    
    /// Creates a Channel from an M3UItem
    static func from(_ item: M3UItem, channelNumber: Int? = nil) -> Channel {
        Channel(
            id: item.id,
            name: item.name,
            logoURL: item.logoURL,
            streamURL: item.streamURL,
            category: item.groupTitle,
            channelNumber: channelNumber,
            tvgId: item.tvgId
        )
    }
}

// MARK: - Channel List Helpers
extension Array where Element == Channel {
    /// Groups channels by their category
    var groupedByCategory: [String: [Channel]] {
        Dictionary(grouping: self) { $0.category }
    }
    
    /// Returns only favorited channels
    var favorites: [Channel] {
        filter { $0.isFavorite }
    }
    
    /// Returns channels sorted by channel number
    var sortedByNumber: [Channel] {
        sorted { ($0.channelNumber ?? Int.max) < ($1.channelNumber ?? Int.max) }
    }
}
