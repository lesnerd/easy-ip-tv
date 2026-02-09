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
    @Published var loadingCategoryIds: Set<String> = []
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
    /// Max number of categories to keep in memory per content type
    static let maxCachedCategories = 30
    
    // MARK: - Private Properties
    
    private let parser = M3UParser()
    private let xtreamService = XtreamCodesService()
    private let stalkerService = StalkerPortalService()
    private let storage = StorageService.shared
    
    private var isLoadingInProgress = false
    private var hasLoadedOnce = false
    
    /// The type of playlist currently loaded
    private var currentPlaylistType: StorageService.PlaylistType = .m3u
    
    /// Cached credentials for on-demand loading (Xtream Codes)
    private var cachedCredentials: (baseURL: String, username: String, password: String)?
    
    /// Cached credentials for Stalker Portal
    private var cachedStalkerCredentials: (portalURL: String, macAddress: String, token: String)?
    
    /// Cache of loaded category items (Published for SwiftUI updates)
    @Published private(set) var channelCache: [String: [Channel]] = [:]
    @Published private(set) var movieCache: [String: [Movie]] = [:]
    @Published private(set) var showCache: [String: [Show]] = [:]
    
    /// Tracks access order for LRU eviction (most recent at end)
    private var channelCacheOrder: [String] = []
    private var movieCacheOrder: [String] = []
    private var showCacheOrder: [String] = []
    
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
    
    /// The current language priority configuration
    @Published var languagePriorityConfig: LanguagePriorityConfig = .empty
    
    /// Categories filtered by a specific language
    func categories(for languageId: String) -> [CategoryInfo] {
        liveCategories.filter { IPTVLanguage.detect(from: $0.name)?.id == languageId }
    }
    
    /// Categories that don't match any known language
    var uncategorizedLanguageCategories: [CategoryInfo] {
        liveCategories.filter { IPTVLanguage.detect(from: $0.name) == nil }
    }
    
    /// The preferred language IDs that have matching categories
    var activePreferredLanguages: [String] {
        languagePriorityConfig.preferred.filter { langId in
            liveCategories.contains { IPTVLanguage.byId[langId]?.matches($0.name) == true }
        }
    }
    
    /// Updates language priority and re-sorts all categories
    func updateLanguagePriority(_ config: LanguagePriorityConfig) {
        languagePriorityConfig = config
        storage.saveLanguagePriority(config)
        resortCategories()
    }
    
    // MARK: - Initialization
    
    init() {
        languagePriorityConfig = storage.getLanguagePriority()
        setupMemoryWarningObserver()
        Task {
            await loadCategories()
        }
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        #endif
    }
    
    /// Sheds memory by evicting non-essential cached categories
    private func handleMemoryWarning() {
        let keepCount = 5 // Keep only the 5 most recently accessed categories per type
        
        evictChannelCache(keepCount: keepCount)
        evictMovieCache(keepCount: keepCount)
        evictShowCache(keepCount: keepCount)
        
        // Also trim image cache
        ImageCacheManager.shared.trimMemoryCache()
        
        print("[Memory] Warning received - evicted caches, kept \(keepCount) per type")
    }
    
    /// Evicts the oldest channel cache entries, keeping the most recent `keepCount`
    private func evictChannelCache(keepCount: Int) {
        guard channelCacheOrder.count > keepCount else { return }
        let toEvict = channelCacheOrder.prefix(channelCacheOrder.count - keepCount)
        for name in toEvict {
            channelCache.removeValue(forKey: name)
        }
        channelCacheOrder = Array(channelCacheOrder.suffix(keepCount))
    }
    
    /// Evicts the oldest movie cache entries
    private func evictMovieCache(keepCount: Int) {
        guard movieCacheOrder.count > keepCount else { return }
        let toEvict = movieCacheOrder.prefix(movieCacheOrder.count - keepCount)
        for name in toEvict {
            movieCache.removeValue(forKey: name)
        }
        movieCacheOrder = Array(movieCacheOrder.suffix(keepCount))
    }
    
    /// Evicts the oldest show cache entries
    private func evictShowCache(keepCount: Int) {
        guard showCacheOrder.count > keepCount else { return }
        let toEvict = showCacheOrder.prefix(showCacheOrder.count - keepCount)
        for name in toEvict {
            showCache.removeValue(forKey: name)
        }
        showCacheOrder = Array(showCacheOrder.suffix(keepCount))
    }
    
    /// Tracks a cache access for LRU ordering
    private func touchCacheOrder(_ name: String, order: inout [String]) {
        order.removeAll { $0 == name }
        order.append(name)
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
            let type = StorageService.playlistType(for: url)
            currentPlaylistType = type
            
            switch type {
            case .xtreamCodes:
                await loadXtreamCodesCategories(from: url)
            case .stalkerPortal:
                await loadStalkerPortalCategories(from: url)
            case .m3u:
                await loadM3UContent(from: url)
            }
            
            // Re-sort after all categories loaded to apply saved language priorities
            resortCategories()
            
            // Load featured content AFTER sorting so it picks from the highest-priority category
            if currentPlaylistType == .xtreamCodes {
                await loadFeaturedContent()
            }
        }
        
        hasLoadedOnce = true
        isLoading = false
        isLoadingInProgress = false
    }
    
    // MARK: - Xtream Codes Loading
    
    private func loadXtreamCodesCategories(from url: URL) async {
        guard let credentials = XtreamCodesService.extractCredentials(from: url) else { return }
        
        cachedCredentials = credentials
        
        do {
            _ = try await xtreamService.authenticate(
                baseURL: credentials.baseURL,
                username: credentials.username,
                password: credentials.password
            )
            
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
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Stalker Portal Loading
    
    private func loadStalkerPortalCategories(from url: URL) async {
        guard let credentials = StalkerPortalService.extractCredentials(from: url) else { return }
        
        do {
            let token = try await stalkerService.authenticate(
                portalURL: credentials.portalURL,
                macAddress: credentials.macAddress
            )
            
            cachedStalkerCredentials = (credentials.portalURL, credentials.macAddress, token)
            
            // Load categories in parallel
            async let liveTask = stalkerService.getLiveCategories(
                portalURL: credentials.portalURL,
                macAddress: credentials.macAddress,
                token: token
            )
            
            async let vodTask = try? stalkerService.getVodCategories(
                portalURL: credentials.portalURL,
                macAddress: credentials.macAddress,
                token: token
            )
            
            async let seriesTask = try? stalkerService.getSeriesCategories(
                portalURL: credentials.portalURL,
                macAddress: credentials.macAddress,
                token: token
            )
            
            let (live, vod, series) = await (try liveTask, vodTask, seriesTask)
            
            liveCategories = live.compactMap { cat -> CategoryInfo? in
                guard let id = cat.id, let name = cat.title else { return nil }
                return CategoryInfo(id: id, name: name)
            }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
            
            if let vod = vod {
                vodCategories = vod.compactMap { cat -> CategoryInfo? in
                    guard let id = cat.id, let name = cat.title else { return nil }
                    return CategoryInfo(id: id, name: name)
                }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
            }
            
            if let series = series {
                seriesCategories = series.compactMap { cat -> CategoryInfo? in
                    guard let id = cat.id, let name = cat.title else { return nil }
                    return CategoryInfo(id: id, name: name)
                }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
            }
            
            hasContent = !liveCategories.isEmpty || !vodCategories.isEmpty || !seriesCategories.isEmpty
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - M3U Loading
    
    private func loadM3UContent(from url: URL) async {
        do {
            let content = try await parser.parse(from: url)
            
            // Group channels by category
            let channelGroups = Dictionary(grouping: content.channels) { $0.category }
            for (category, channels) in channelGroups {
                channelCache[category] = channels
                touchCacheOrder(category, order: &channelCacheOrder)
            }
            
            liveCategories = channelGroups.keys.map { name in
                CategoryInfo(id: name, name: name, itemCount: channelGroups[name]?.count)
            }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
            
            // Group movies by category
            let movieGroups = Dictionary(grouping: content.movies) { $0.category }
            for (category, movies) in movieGroups {
                movieCache[category] = movies
                touchCacheOrder(category, order: &movieCacheOrder)
            }
            
            vodCategories = movieGroups.keys.map { name in
                CategoryInfo(id: name, name: name, itemCount: movieGroups[name]?.count)
            }.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
            
            // Set featured from first loaded content
            if let firstChannels = channelGroups.values.first {
                featuredChannels = Array(firstChannels.prefix(Self.maxFeaturedItems))
            }
            if let firstMovies = movieGroups.values.first {
                featuredMovies = Array(firstMovies.prefix(Self.maxFeaturedItems))
            }
            
            hasContent = !liveCategories.isEmpty || !vodCategories.isEmpty
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Featured Content
    
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
    
    /// Check if a specific category is currently loading
    func isCategoryLoading(_ category: CategoryInfo) -> Bool {
        loadingCategoryIds.contains(category.id)
    }
    
    /// Loads channels for a specific category (on-demand)
    func loadChannelsForCategory(_ category: CategoryInfo) async {
        // Check cache first
        if channelCache[category.name] != nil { return }
        // Prevent duplicate loads
        guard !loadingCategoryIds.contains(category.id) else { return }
        
        // For M3U, channels are loaded upfront - nothing to do
        if currentPlaylistType == .m3u { return }
        
        // Route to correct service
        if currentPlaylistType == .stalkerPortal {
            await loadStalkerChannelsForCategory(category)
            return
        }
        
        guard let credentials = cachedCredentials else { return }
        
        isLoadingCategory = true
        loadingCategoryIds.insert(category.id)
        
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
            touchCacheOrder(category.name, order: &channelCacheOrder)
            evictChannelCache(keepCount: Self.maxCachedCategories)
            self.channels = processedChannels
            
        } catch {
            print("Failed to load channels for category \(category.name): \(error)")
        }
        
        loadingCategoryIds.remove(category.id)
        isLoadingCategory = !loadingCategoryIds.isEmpty
    }
    
    /// Loads Stalker Portal channels for a category
    private func loadStalkerChannelsForCategory(_ category: CategoryInfo) async {
        guard let creds = cachedStalkerCredentials else { return }
        
        isLoadingCategory = true
        loadingCategoryIds.insert(category.id)
        
        do {
            let items = try await stalkerService.getLiveChannels(
                portalURL: creds.portalURL,
                macAddress: creds.macAddress,
                token: creds.token,
                categoryId: category.id
            )
            
            var channelNumber = 1
            let channels: [Channel] = items.compactMap { item -> Channel? in
                guard let id = item.id, let name = item.name, let cmd = item.cmd,
                      let streamURL = StalkerPortalService.extractStreamURL(from: cmd) else { return nil }
                let logoURL = item.logo.flatMap { URL(string: $0) }
                let ch = Channel(id: id, name: name, logoURL: logoURL, streamURL: streamURL,
                                 category: category.name, channelNumber: channelNumber)
                channelNumber += 1
                return ch
            }
            
            let processed = channels.map { ch -> Channel in
                var updated = ch
                updated.isFavorite = storage.isFavorite(channelId: ch.id)
                return updated
            }
            
            channelCache[category.name] = processed
            touchCacheOrder(category.name, order: &channelCacheOrder)
            evictChannelCache(keepCount: Self.maxCachedCategories)
            self.channels = processed
        } catch {
            print("Failed to load Stalker channels for \(category.name): \(error)")
        }
        
        loadingCategoryIds.remove(category.id)
        isLoadingCategory = !loadingCategoryIds.isEmpty
    }
    
    /// Loads movies for a specific category (on-demand)
    func loadMoviesForCategory(_ category: CategoryInfo) async {
        // Check cache first
        if movieCache[category.name] != nil {
            movies = movieCache[category.name] ?? []
            return
        }
        // Prevent duplicate loads
        guard !loadingCategoryIds.contains(category.id) else { return }
        
        if currentPlaylistType == .m3u { return }
        // TODO: Add Stalker Portal VOD loading when needed
        
        guard let credentials = cachedCredentials else { return }
        
        isLoadingCategory = true
        loadingCategoryIds.insert(category.id)
        
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
            touchCacheOrder(category.name, order: &movieCacheOrder)
            evictMovieCache(keepCount: Self.maxCachedCategories)
            self.movies = processedMovies
            
        } catch {
            print("Failed to load movies for category \(category.name): \(error)")
        }
        
        loadingCategoryIds.remove(category.id)
        isLoadingCategory = !loadingCategoryIds.isEmpty
    }
    
    /// Loads shows for a specific category (on-demand)
    func loadShowsForCategory(_ category: CategoryInfo) async {
        // Check cache first
        if showCache[category.name] != nil {
            shows = showCache[category.name] ?? []
            return
        }
        // Prevent duplicate loads
        guard !loadingCategoryIds.contains(category.id) else { return }
        
        if currentPlaylistType == .m3u { return }
        // TODO: Add Stalker Portal series loading when needed
        
        guard let credentials = cachedCredentials else { return }
        
        isLoadingCategory = true
        loadingCategoryIds.insert(category.id)
        
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
            touchCacheOrder(category.name, order: &showCacheOrder)
            evictShowCache(keepCount: Self.maxCachedCategories)
            self.shows = processedShows
            
        } catch {
            print("Failed to load shows for category \(category.name): \(error)")
        }
        
        loadingCategoryIds.remove(category.id)
        isLoadingCategory = !loadingCategoryIds.isEmpty
    }
    
    /// Gets priority for category sorting (lower = shown first, higher = shown last)
    private func categoryPriority(_ category: String) -> Int {
        languagePriorityConfig.priority(for: category)
    }
    
    /// Re-sorts all category arrays based on current language priority
    private func resortCategories() {
        // Use .sorted() to create new arrays, ensuring @Published fires properly
        liveCategories = liveCategories.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
        vodCategories = vodCategories.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
        seriesCategories = seriesCategories.sorted { categoryPriority($0.name) < categoryPriority($1.name) }
    }
    
    /// Refreshes all content
    func refresh() async {
        channelCache.removeAll()
        movieCache.removeAll()
        showCache.removeAll()
        channelCacheOrder.removeAll()
        movieCacheOrder.removeAll()
        showCacheOrder.removeAll()
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
        if channelCache[category] != nil {
            touchCacheOrder(category, order: &channelCacheOrder)
        }
        return channelCache[category] ?? []
    }
    
    func movies(in category: String) -> [Movie] {
        if movieCache[category] != nil {
            touchCacheOrder(category, order: &movieCacheOrder)
        }
        return movieCache[category] ?? []
    }
    
    func shows(in category: String) -> [Show] {
        if showCache[category] != nil {
            touchCacheOrder(category, order: &showCacheOrder)
        }
        return showCache[category] ?? []
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
