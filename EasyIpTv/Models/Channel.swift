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
    let epgChannelId: String?
    let hasCatchup: Bool
    let catchupDays: Int?
    let streamId: Int?
    
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
        epgChannelId: String? = nil,
        hasCatchup: Bool = false,
        catchupDays: Int? = nil,
        streamId: Int? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.category = category
        self.channelNumber = channelNumber
        self.tvgId = tvgId
        self.epgChannelId = epgChannelId
        self.hasCatchup = hasCatchup
        self.catchupDays = catchupDays
        self.streamId = streamId
        self.isFavorite = isFavorite
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, logoURL, streamURL, category, channelNumber
        case tvgId, epgChannelId, hasCatchup, catchupDays, streamId, isFavorite
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        logoURL = try container.decodeIfPresent(URL.self, forKey: .logoURL)
        streamURL = try container.decode(URL.self, forKey: .streamURL)
        category = try container.decode(String.self, forKey: .category)
        channelNumber = try container.decodeIfPresent(Int.self, forKey: .channelNumber)
        tvgId = try container.decodeIfPresent(String.self, forKey: .tvgId)
        epgChannelId = try container.decodeIfPresent(String.self, forKey: .epgChannelId)
        hasCatchup = try container.decodeIfPresent(Bool.self, forKey: .hasCatchup) ?? false
        catchupDays = try container.decodeIfPresent(Int.self, forKey: .catchupDays)
        streamId = try container.decodeIfPresent(Int.self, forKey: .streamId)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
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
