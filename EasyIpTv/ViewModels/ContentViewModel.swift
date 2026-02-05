import Foundation
import SwiftUI

/// ViewModel for managing content (channels, movies, shows)
@MainActor
class ContentViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var channels: [Channel] = []
    @Published var movies: [Movie] = []
    @Published var shows: [Show] = []
    @Published var categories: [String: ContentType] = [:]
    
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var hasContent: Bool = false
    
    @Published var selectedCategory: String?
    @Published var searchText: String = ""
    
    // MARK: - Private Properties
    
    private let parser = M3UParser()
    private let xtreamService = XtreamCodesService()
    private let storage = StorageService.shared
    
    // MARK: - Computed Properties
    
    /// Channels grouped by category
    var channelsByCategory: [String: [Channel]] {
        channels.groupedByCategory
    }
    
    /// Movies grouped by category
    var moviesByCategory: [String: [Movie]] {
        movies.groupedByCategory
    }
    
    /// Shows grouped by category
    var showsByCategory: [String: [Show]] {
        shows.groupedByCategory
    }
    
    /// All channel categories
    var channelCategories: [String] {
        Array(channelsByCategory.keys).sorted()
    }
    
    /// All movie categories
    var movieCategories: [String] {
        Array(moviesByCategory.keys).sorted()
    }
    
    /// All show categories
    var showCategories: [String] {
        Array(showsByCategory.keys).sorted()
    }
    
    /// Filtered channels based on search and category
    var filteredChannels: [Channel] {
        var result = channels
        
        if let category = selectedCategory, !category.isEmpty {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    /// Filtered movies based on search and category
    var filteredMovies: [Movie] {
        var result = movies
        
        if let category = selectedCategory, !category.isEmpty {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    /// Filtered shows based on search and category
    var filteredShows: [Show] {
        var result = shows
        
        if let category = selectedCategory, !category.isEmpty {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadContent()
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads content from all configured playlists
    func loadContent() async {
        let playlistURLs = storage.playlistURLs
        
        guard !playlistURLs.isEmpty else {
            hasContent = false
            return
        }
        
        isLoading = true
        error = nil
        
        var allChannels: [Channel] = []
        var allMovies: [Movie] = []
        var allShows: [Show] = []
        var allCategories: [String: ContentType] = [:]
        
        for url in playlistURLs {
            do {
                // Check if this is an Xtream Codes URL
                if XtreamCodesService.isXtreamCodesURL(url),
                   let credentials = XtreamCodesService.extractCredentials(from: url) {
                    let content = try await loadXtreamCodesContent(
                        baseURL: credentials.baseURL,
                        username: credentials.username,
                        password: credentials.password
                    )
                    allChannels.append(contentsOf: content.channels)
                    allMovies.append(contentsOf: content.movies)
                    allShows.append(contentsOf: content.shows)
                    allCategories.merge(content.categories) { current, _ in current }
                } else {
                    // Standard M3U parsing
                    let content = try await parser.parse(from: url)
                    allChannels.append(contentsOf: content.channels)
                    allMovies.append(contentsOf: content.movies)
                    allShows.append(contentsOf: content.shows)
                    allCategories.merge(content.categories) { current, _ in current }
                }
            } catch {
                // Silently continue if playlist fails to load
            }
        }
        
        // Apply favorite status
        channels = allChannels.map { channel in
            var updated = channel
            updated.isFavorite = storage.isFavorite(channelId: channel.id)
            return updated
        }
        
        movies = allMovies.map { movie in
            var updated = movie
            updated.isFavorite = storage.isFavorite(movieId: movie.id)
            updated.watchProgress = storage.getWatchProgress(for: movie.id)
            return updated
        }
        
        shows = allShows.map { show in
            var updated = show
            updated.isFavorite = storage.isFavorite(showId: show.id)
            return updated
        }
        
        categories = allCategories
        hasContent = !channels.isEmpty || !movies.isEmpty || !shows.isEmpty
        isLoading = false
    }
    
    /// Refreshes content
    func refresh() async {
        await loadContent()
    }
    
    /// Gets a channel by ID
    func channel(withId id: String) -> Channel? {
        channels.first { $0.id == id }
    }
    
    /// Gets a movie by ID
    func movie(withId id: String) -> Movie? {
        movies.first { $0.id == id }
    }
    
    /// Gets a show by ID
    func show(withId id: String) -> Show? {
        shows.first { $0.id == id }
    }
    
    /// Gets channels for a specific category
    func channels(in category: String) -> [Channel] {
        channels.filter { $0.category == category }
    }
    
    /// Gets movies for a specific category
    func movies(in category: String) -> [Movie] {
        movies.filter { $0.category == category }
    }
    
    /// Gets shows for a specific category
    func shows(in category: String) -> [Show] {
        shows.filter { $0.category == category }
    }
    
    /// Toggles favorite for a channel
    func toggleFavorite(channel: Channel) {
        storage.toggleFavorite(channelId: channel.id)
        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            channels[index].isFavorite.toggle()
        }
    }
    
    /// Toggles favorite for a movie
    func toggleFavorite(movie: Movie) {
        storage.toggleFavorite(movieId: movie.id)
        if let index = movies.firstIndex(where: { $0.id == movie.id }) {
            movies[index].isFavorite.toggle()
        }
    }
    
    /// Toggles favorite for a show
    func toggleFavorite(show: Show) {
        storage.toggleFavorite(showId: show.id)
        if let index = shows.firstIndex(where: { $0.id == show.id }) {
            shows[index].isFavorite.toggle()
        }
    }
    
    /// Gets the next channel in the list
    func nextChannel(after channel: Channel) -> Channel? {
        guard let currentIndex = channels.firstIndex(where: { $0.id == channel.id }) else {
            return nil
        }
        let nextIndex = (currentIndex + 1) % channels.count
        return channels[nextIndex]
    }
    
    /// Gets the previous channel in the list
    func previousChannel(before channel: Channel) -> Channel? {
        guard let currentIndex = channels.firstIndex(where: { $0.id == channel.id }) else {
            return nil
        }
        let previousIndex = currentIndex == 0 ? channels.count - 1 : currentIndex - 1
        return channels[previousIndex]
    }
    
    /// Gets nearby channels for the channel navigator
    func nearbyChannels(around channel: Channel, count: Int = 5) -> [Channel] {
        guard let currentIndex = channels.firstIndex(where: { $0.id == channel.id }) else {
            return []
        }
        
        var result: [Channel] = []
        let halfCount = count / 2
        
        for offset in -halfCount...halfCount {
            let index = (currentIndex + offset + channels.count) % channels.count
            result.append(channels[index])
        }
        
        return result
    }
    
    // MARK: - Xtream Codes Support
    
    /// Loads content from Xtream Codes API
    private func loadXtreamCodesContent(baseURL: String, username: String, password: String) async throws -> M3UParser.ParsedContent {
        // First authenticate
        _ = try await xtreamService.authenticate(baseURL: baseURL, username: username, password: password)
        
        // Load categories for mapping
        let liveCategories = try await xtreamService.getLiveCategories(baseURL: baseURL, username: username, password: password)
        let vodCategories = try await xtreamService.getVodCategories(baseURL: baseURL, username: username, password: password)
        
        let liveCategoryMap = Dictionary(uniqueKeysWithValues: liveCategories.compactMap { cat -> (String, String)? in
            guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
            return (id, name)
        })
        
        let vodCategoryMap = Dictionary(uniqueKeysWithValues: vodCategories.compactMap { cat -> (String, String)? in
            guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
            return (id, name)
        })
        
        // Load live streams
        let liveStreams = try await xtreamService.getLiveStreams(baseURL: baseURL, username: username, password: password)
        
        var channelNumber = 1
        let channels: [Channel] = liveStreams.compactMap { stream -> Channel? in
            guard let streamId = stream.streamId,
                  let name = stream.name,
                  let streamURL = xtreamService.buildLiveStreamURL(baseURL: baseURL, username: username, password: password, streamId: streamId) else {
                return nil
            }
            
            let categoryName = stream.categoryId.flatMap { liveCategoryMap[$0] } ?? "Uncategorized"
            let logoURL = stream.streamIcon.flatMap { URL(string: $0) }
            
            let channel = Channel(
                id: "\(streamId)",
                name: name,
                logoURL: logoURL,
                streamURL: streamURL,
                category: categoryName,
                channelNumber: channelNumber
            )
            channelNumber += 1
            return channel
        }
        
        // Load VOD streams (movies)
        let vodStreams = try await xtreamService.getVodStreams(baseURL: baseURL, username: username, password: password)
        
        let movies: [Movie] = vodStreams.compactMap { stream -> Movie? in
            guard let streamId = stream.streamId,
                  let name = stream.name,
                  let ext = stream.containerExtension,
                  let streamURL = xtreamService.buildVodStreamURL(baseURL: baseURL, username: username, password: password, streamId: streamId, extension: ext) else {
                return nil
            }
            
            let categoryName = stream.categoryId.flatMap { vodCategoryMap[$0] } ?? "Uncategorized"
            let posterURL = stream.streamIcon.flatMap { URL(string: $0) }
            
            return Movie(
                id: "\(streamId)",
                title: name,
                posterURL: posterURL,
                streamURL: streamURL,
                category: categoryName
            )
        }
        
        // Load series categories and series list (non-blocking - if it fails, continue with empty shows)
        var shows: [Show] = []
        var seriesCategoryMap: [String: String] = [:]
        
        do {
            let seriesCategories = try await xtreamService.getSeriesCategories(baseURL: baseURL, username: username, password: password)
            seriesCategoryMap = Dictionary(uniqueKeysWithValues: seriesCategories.compactMap { cat -> (String, String)? in
                guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                return (id, name)
            })
            
            let seriesList = try await xtreamService.getSeries(baseURL: baseURL, username: username, password: password)
            
            // Create Show objects from series list
            shows = seriesList.compactMap { series -> Show? in
                guard let seriesId = series.seriesId,
                      let name = series.name else {
                    return nil
                }
                
                let categoryName = series.categoryId.flatMap { seriesCategoryMap[$0] } ?? "Uncategorized"
                let posterURL = series.cover.flatMap { URL(string: $0) }
                let rating = series.rating.flatMap { Double($0) }
                
                return Show(
                    id: "\(seriesId)",
                    title: name,
                    posterURL: posterURL,
                    category: categoryName,
                    description: series.plot,
                    rating: rating,
                    seasons: [] // Episodes loaded on demand
                )
            }
        } catch {
            // Continue without shows if series loading fails
        }
        
        // Build categories map
        var categoriesMap: [String: ContentType] = [:]
        for (_, name) in liveCategoryMap {
            categoriesMap[name] = .liveTV
        }
        for (_, name) in vodCategoryMap {
            categoriesMap[name] = .movie
        }
        for (_, name) in seriesCategoryMap {
            categoriesMap[name] = .series
        }
        
        return M3UParser.ParsedContent(
            channels: channels,
            movies: movies,
            shows: shows,
            categories: categoriesMap
        )
    }
}
