import Foundation
import SwiftUI

/// ViewModel for managing content with lazy loading
/// Loads only categories initially, then loads items on-demand per category
@MainActor
class ContentViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Category information (lightweight, loaded at startup)
    @Published var liveCategories: [CategoryInfo] = []
    @Published var vodCategories: [CategoryInfo] = []
    @Published var seriesCategories: [CategoryInfo] = []
    
    /// Currently loaded items (loaded on-demand per category)
    @Published var channels: [Channel] = []
    @Published var movies: [Movie] = []
    @Published var shows: [Show] = []
    
    /// Featured items for home screen (small subset)
    @Published var featuredChannels: [Channel] = []
    @Published var featuredMovies: [Movie] = []
    @Published var featuredShows: [Show] = []
    
    @Published var isLoading: Bool = false
    @Published var isLoadingCategory: Bool = false
    @Published var error: Error?
    @Published var hasContent: Bool = false
    
    @Published var selectedCategory: String?
    @Published var searchText: String = ""
    
    // MARK: - Category Info
    
    struct CategoryInfo: Identifiable, Hashable, Codable {
        let id: String
        let name: String
        var itemCount: Int?
        
        init(id: String, name: String, itemCount: Int? = nil) {
            self.id = id
            self.name = name
            self.itemCount = itemCount
        }
    }
    
    // MARK: - Constants
    
    /// Max items to load per category
    static let maxItemsPerCategory = 200
    /// Max featured items
    static let maxFeaturedItems = 20
    /// Max items for search results
    static let maxSearchResults = 100
    
    // MARK: - Private Properties
    
    private let parser = M3UParser()
    private let xtreamService = XtreamCodesService()
    private let storage = StorageService.shared
    
    private var isLoadingInProgress = false
    private var hasLoadedOnce = false
    
    /// Cached credentials for on-demand loading
    private var cachedCredentials: (baseURL: String, username: String, password: String)?
    
    /// Cache of loaded category items (Published for SwiftUI updates)
    @Published private(set) var channelCache: [String: [Channel]] = [:]
    @Published private(set) var movieCache: [String: [Movie]] = [:]
    @Published private(set) var showCache: [String: [Show]] = [:]
    
    // MARK: - Computed Properties
    
    /// All category names for compatibility
    var categories: [String: ContentType] {
        var result: [String: ContentType] = [:]
        for cat in liveCategories { result[cat.name] = .liveTV }
        for cat in vodCategories { result[cat.name] = .movie }
        for cat in seriesCategories { result[cat.name] = .series }
        return result
    }
    
    /// Channels grouped by category (from cache)
    var channelsByCategory: [String: [Channel]] {
        channelCache
    }
    
    /// Movies grouped by category (from cache)
    var moviesByCategory: [String: [Movie]] {
        movieCache
    }
    
    /// Shows grouped by category (from cache)
    var showsByCategory: [String: [Show]] {
        showCache
    }
    
    /// All loaded channels from all categories
    var allLoadedChannels: [Channel] {
        channelCache.values.flatMap { $0 }
    }
    
    /// All loaded movies from all categories
    var allLoadedMovies: [Movie] {
        movieCache.values.flatMap { $0 }
    }
    
    /// All loaded shows from all categories
    var allLoadedShows: [Show] {
        showCache.values.flatMap { $0 }
    }
    
    /// Hungarian categories (prioritized)
    var hungarianCategories: [CategoryInfo] {
        liveCategories.filter { detectCountry(from: $0.name) == "hungary" }
    }
    
    /// Israeli categories (prioritized)
    var israeliCategories: [CategoryInfo] {
        liveCategories.filter { detectCountry(from: $0.name) == "israel" }
    }
    
    /// Other categories
    var otherCategories: [CategoryInfo] {
        liveCategories.filter { detectCountry(from: $0.name) == nil }
    }
    
    // MARK: - Country Detection
    
    private func detectCountry(from category: String) -> String? {
        let lowercased = category.lowercased()
        
        if lowercased.contains("hungary") || lowercased.contains("hungarian") ||
           lowercased.contains("magyar") || lowercased.hasPrefix("hu ") ||
           lowercased.hasSuffix(" hu") || lowercased.contains("| hu") {
            return "hungary"
        }
        
        if lowercased.contains("israel") || lowercased.contains("israeli") ||
           lowercased.contains("hebrew") || lowercased.hasPrefix("il ") ||
           lowercased.hasSuffix(" il") || lowercased.contains("| il") {
            return "israel"
        }
        
        if lowercased.contains("arabic") || lowercased.contains("arab") ||
           lowercased.hasPrefix("ar ") || lowercased.hasSuffix(" ar") ||
           lowercased.contains("| ar") || lowercased.contains("العربية") {
            return "arabic"
        }
        
        return nil
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadCategories()
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads only category metadata (fast, lightweight)
    func loadCategories() async {
        guard !isLoadingInProgress else { return }
        
        let playlistURLs = storage.playlistURLs
        guard !playlistURLs.isEmpty else {
            hasContent = false
            return
        }
        
        isLoadingInProgress = true
        isLoading = true
        error = nil
        
        // Process first playlist URL
        if let url = playlistURLs.first {
            if XtreamCodesService.isXtreamCodesURL(url),
               let credentials = XtreamCodesService.extractCredentials(from: url) {
                
                // Cache credentials for on-demand loading
                cachedCredentials = credentials
                
                do {
                    // Authenticate
                    _ = try await xtreamService.authenticate(
                        baseURL: credentials.baseURL,
                        username: credentials.username,
                        password: credentials.password
                    )
                    
                    // Load only categories (fast)
                    async let liveTask = xtreamService.getLiveCategories(
                        baseURL: credentials.baseURL,
                        username: credentials.username,
                        password: credentials.password
                    )
                    
                    async let vodTask = xtreamService.getVodCategories(
                        baseURL: credentials.baseURL,
                        username: credentials.username,
                        password: credentials.password
                    )
                    
                    async let seriesTask = try? xtreamService.getSeriesCategories(
                        baseURL: credentials.baseURL,
                        username: credentials.username,
                        password: credentials.password
                    )
                    
                    let (live, vod, series) = await (try liveTask, try vodTask, seriesTask)
                    
                    // Convert to CategoryInfo
                    liveCategories = live.compactMap { cat -> CategoryInfo? in
                        guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                        return CategoryInfo(id: id, name: name)
                    }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
                    
                    vodCategories = vod.compactMap { cat -> CategoryInfo? in
                        guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                        return CategoryInfo(id: id, name: name)
                    }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
                    
                    if let series = series {
                        seriesCategories = series.compactMap { cat -> CategoryInfo? in
                            guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                            return CategoryInfo(id: id, name: name)
                        }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
                    }
                    
                    hasContent = !liveCategories.isEmpty || !vodCategories.isEmpty || !seriesCategories.isEmpty
                    
                    // Load featured items (small subset for home screen)
                    await loadFeaturedContent()
                    
                } catch {
                    self.error = error
                }
            }
        }
        
        hasLoadedOnce = true
        isLoading = false
        isLoadingInProgress = false
    }
    
    /// Loads a small subset of featured content for the home screen
    private func loadFeaturedContent() async {
        guard let credentials = cachedCredentials else { return }
        
        // Load just first category of each type for featured section
        if let firstLive = liveCategories.first {
            await loadChannelsForCategory(firstLive)
            featuredChannels = Array(channelCache[firstLive.name]?.prefix(Self.maxFeaturedItems) ?? [])
        }
        
        if let firstVod = vodCategories.first {
            await loadMoviesForCategory(firstVod)
            featuredMovies = Array(movieCache[firstVod.name]?.prefix(Self.maxFeaturedItems) ?? [])
        }
    }
    
    /// Loads channels for a specific category (on-demand)
    func loadChannelsForCategory(_ category: CategoryInfo) async {
        // Check cache first
        if channelCache[category.name] != nil { return }
        
        guard let credentials = cachedCredentials else { return }
        
        isLoadingCategory = true
        
        do {
            let streams = try await xtreamService.getLiveStreamsByCategory(
                baseURL: credentials.baseURL,
                username: credentials.username,
                password: credentials.password,
                categoryId: category.id
            )
            
            // Convert to channels (limit count)
            var channelNumber = 1
            let channels: [Channel] = streams.prefix(Self.maxItemsPerCategory).compactMap { stream -> Channel? in
                guard let streamId = stream.streamId,
                      let name = stream.name,
                      let streamURL = xtreamService.buildLiveStreamURL(
                        baseURL: credentials.baseURL,
                        username: credentials.username,
                        password: credentials.password,
                        streamId: streamId
                      ) else { return nil }
                
                let logoURL = stream.streamIcon.flatMap { URL(string: $0) }
                let channel = Channel(
                    id: "\(streamId)",
                    name: name,
                    logoURL: logoURL,
                    streamURL: streamURL,
                    category: category.name,
                    channelNumber: channelNumber
                )
                channelNumber += 1
                return channel
            }
            
            // Apply favorites and cache
            let processedChannels = channels.map { channel in
                var updated = channel
                updated.isFavorite = storage.isFavorite(channelId: channel.id)
                return updated
            }
            
            channelCache[category.name] = processedChannels
            self.channels = processedChannels
            
        } catch {
            print("Failed to load channels for category \(category.name): \(error)")
        }
        
        isLoadingCategory = false
    }
    
    /// Loads movies for a specific category (on-demand)
    func loadMoviesForCategory(_ category: CategoryInfo) async {
        // Check cache first
        if movieCache[category.name] != nil {
            movies = movieCache[category.name] ?? []
            return
        }
        
        guard let credentials = cachedCredentials else { return }
        
        isLoadingCategory = true
        
        do {
            let streams = try await xtreamService.getVodStreamsByCategory(
                baseURL: credentials.baseURL,
                username: credentials.username,
                password: credentials.password,
                categoryId: category.id
            )
            
            // Convert to movies (limit count)
            let movies: [Movie] = streams.prefix(Self.maxItemsPerCategory).compactMap { stream -> Movie? in
                guard let streamId = stream.streamId,
                      let name = stream.name,
                      let ext = stream.containerExtension,
                      let streamURL = xtreamService.buildVodStreamURL(
                        baseURL: credentials.baseURL,
                        username: credentials.username,
                        password: credentials.password,
                        streamId: streamId,
                        extension: ext
                      ) else { return nil }
                
                let posterURL = stream.streamIcon.flatMap { URL(string: $0) }
                return Movie(
                    id: "\(streamId)",
                    title: name,
                    posterURL: posterURL,
                    streamURL: streamURL,
                    category: category.name
                )
            }
            
            // Apply favorites and cache
            let processedMovies = movies.map { movie in
                var updated = movie
                updated.isFavorite = storage.isFavorite(movieId: movie.id)
                updated.watchProgress = storage.getWatchProgress(for: movie.id)
                return updated
            }
            
            movieCache[category.name] = processedMovies
            self.movies = processedMovies
            
        } catch {
            print("Failed to load movies for category \(category.name): \(error)")
        }
        
        isLoadingCategory = false
    }
    
    /// Loads shows for a specific category (on-demand)
    func loadShowsForCategory(_ category: CategoryInfo) async {
        // Check cache first
        if showCache[category.name] != nil {
            shows = showCache[category.name] ?? []
            return
        }
        
        guard let credentials = cachedCredentials else { return }
        
        isLoadingCategory = true
        
        do {
            let seriesList = try await xtreamService.getSeriesByCategory(
                baseURL: credentials.baseURL,
                username: credentials.username,
                password: credentials.password,
                categoryId: category.id
            )
            
            // Convert to shows (limit count)
            let shows: [Show] = seriesList.prefix(Self.maxItemsPerCategory).compactMap { series -> Show? in
                guard let seriesId = series.seriesId, let name = series.name else { return nil }
                
                let posterURL = series.cover.flatMap { URL(string: $0) }
                let rating = series.rating.flatMap { Double($0) }
                
                return Show(
                    id: "\(seriesId)",
                    title: name,
                    posterURL: posterURL,
                    category: category.name,
                    description: series.plot,
                    rating: rating,
                    seasons: []
                )
            }
            
            // Apply favorites and cache
            let processedShows = shows.map { show in
                var updated = show
                updated.isFavorite = storage.isFavorite(showId: show.id)
                return updated
            }
            
            showCache[category.name] = processedShows
            self.shows = processedShows
            
        } catch {
            print("Failed to load shows for category \(category.name): \(error)")
        }
        
        isLoadingCategory = false
    }
    
    /// Gets priority for category sorting (lower = shown first, higher = shown last)
    private func categoryPriority(_ category: String) -> Int {
        if let country = detectCountry(from: category) {
            switch country {
            case "hungary": return 0
            case "israel": return 1
            case "arabic": return 99 // Push Arabic to the end
            default: return 2
            }
        }
        return 2
    }
    
    /// Refreshes all content
    func refresh() async {
        channelCache.removeAll()
        movieCache.removeAll()
        showCache.removeAll()
        hasLoadedOnce = false
        isLoadingInProgress = false
        await loadCategories()
    }
    
    /// Loads content if needed
    func loadContentIfNeeded() async {
        guard !hasLoadedOnce && !isLoadingInProgress else { return }
        await loadCategories()
    }
    
    // MARK: - Compatibility Methods
    
    func channel(withId id: String) -> Channel? {
        for channels in channelCache.values {
            if let channel = channels.first(where: { $0.id == id }) {
                return channel
            }
        }
        return nil
    }
    
    func movie(withId id: String) -> Movie? {
        for movies in movieCache.values {
            if let movie = movies.first(where: { $0.id == id }) {
                return movie
            }
        }
        return nil
    }
    
    func show(withId id: String) -> Show? {
        for shows in showCache.values {
            if let show = shows.first(where: { $0.id == id }) {
                return show
            }
        }
        return nil
    }
    
    func channels(in category: String) -> [Channel] {
        channelCache[category] ?? []
    }
    
    func movies(in category: String) -> [Movie] {
        movieCache[category] ?? []
    }
    
    func shows(in category: String) -> [Show] {
        showCache[category] ?? []
    }
    
    func toggleFavorite(channel: Channel) {
        storage.toggleFavorite(channelId: channel.id)
        // Update in cache
        for (cat, var channels) in channelCache {
            if let index = channels.firstIndex(where: { $0.id == channel.id }) {
                channels[index].isFavorite.toggle()
                channelCache[cat] = channels
            }
        }
    }
    
    /// Adds all channels in a category to favorites
    func addCategoryToFavorites(_ category: CategoryInfo) {
        let channels = channelCache[category.name] ?? []
        let channelIds = channels.map { $0.id }
        storage.addFavorites(channelIds: channelIds)
        
        // Update in cache
        var updatedChannels = channels
        for i in updatedChannels.indices {
            updatedChannels[i].isFavorite = true
        }
        channelCache[category.name] = updatedChannels
    }
    
    /// Removes all channels in a category from favorites
    func removeCategoryFromFavorites(_ category: CategoryInfo) {
        let channels = channelCache[category.name] ?? []
        let channelIds = channels.map { $0.id }
        storage.removeFavorites(channelIds: channelIds)
        
        // Update in cache
        var updatedChannels = channels
        for i in updatedChannels.indices {
            updatedChannels[i].isFavorite = false
        }
        channelCache[category.name] = updatedChannels
    }
    
    /// Checks if all channels in a category are favorites
    func isCategoryAllFavorites(_ category: CategoryInfo) -> Bool {
        let channels = channelCache[category.name] ?? []
        guard !channels.isEmpty else { return false }
        return channels.allSatisfy { $0.isFavorite }
    }
    
    func toggleFavorite(movie: Movie) {
        storage.toggleFavorite(movieId: movie.id)
        for (cat, var movies) in movieCache {
            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                movies[index].isFavorite.toggle()
                movieCache[cat] = movies
            }
        }
    }
    
    func toggleFavorite(show: Show) {
        storage.toggleFavorite(showId: show.id)
        for (cat, var shows) in showCache {
            if let index = shows.firstIndex(where: { $0.id == show.id }) {
                shows[index].isFavorite.toggle()
                showCache[cat] = shows
            }
        }
    }
    
    func nextChannel(after channel: Channel) -> Channel? {
        let allChannels = channelCache[channel.category] ?? []
        guard let currentIndex = allChannels.firstIndex(where: { $0.id == channel.id }) else { return nil }
        let nextIndex = (currentIndex + 1) % allChannels.count
        return allChannels[nextIndex]
    }
    
    func previousChannel(before channel: Channel) -> Channel? {
        let allChannels = channelCache[channel.category] ?? []
        guard let currentIndex = allChannels.firstIndex(where: { $0.id == channel.id }) else { return nil }
        let previousIndex = currentIndex == 0 ? allChannels.count - 1 : currentIndex - 1
        return allChannels[previousIndex]
    }
    
    func nearbyChannels(around channel: Channel, count: Int = 5) -> [Channel] {
        let allChannels = channelCache[channel.category] ?? []
        guard let currentIndex = allChannels.firstIndex(where: { $0.id == channel.id }) else { return [] }
        
        var result: [Channel] = []
        let halfCount = count / 2
        
        for offset in -halfCount...halfCount {
            let index = (currentIndex + offset + allChannels.count) % allChannels.count
            result.append(allChannels[index])
        }
        
        return result
    }
}
