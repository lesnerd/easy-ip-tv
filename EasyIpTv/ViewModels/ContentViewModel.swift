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
    
    /// Trending content for home screen (aggregated from top categories, sorted by rating)
    @Published var trendingMovies: [Movie] = []
    @Published var trendingShows: [Show] = []
    @Published var trendingChannels: [Channel] = []
    
    @Published var isLoading: Bool = false
    @Published var isLoadingCategory: Bool = false
    @Published var loadingCategoryIds: Set<String> = []
    @Published var error: Error?
    @Published var hasContent: Bool = false
    @Published var isContentReady: Bool = false
    
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
    #if os(tvOS)
    static let maxCachedCategories = 50
    #else
    static let maxCachedCategories = 30
    #endif
    
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
    
    /// Finds an episode by ID across all loaded shows
    func findEpisode(byId episodeId: String) -> Episode? {
        for show in allLoadedShows {
            for season in show.seasons {
                if let episode = season.episodes.first(where: { $0.id == episodeId }) {
                    return episode
                }
            }
        }
        return nil
    }
    
    /// Finds the next episode after the given one within the same show
    func findNextEpisode(afterEpisodeId episodeId: String, inShowId showId: String?) -> (episode: Episode, seasonNumber: Int)? {
        let targetShow: Show?
        if let showId {
            targetShow = show(withId: showId)
        } else {
            targetShow = allLoadedShows.first { show in
                show.seasons.contains { season in
                    season.episodes.contains { $0.id == episodeId }
                }
            }
        }
        guard let show = targetShow else { return nil }
        let sortedSeasons = show.seasons.sorted { $0.seasonNumber < $1.seasonNumber }
        
        for (sIdx, season) in sortedSeasons.enumerated() {
            let sortedEpisodes = season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
            if let eIdx = sortedEpisodes.firstIndex(where: { $0.id == episodeId }) {
                if eIdx + 1 < sortedEpisodes.count {
                    return (sortedEpisodes[eIdx + 1], season.seasonNumber)
                }
                if sIdx + 1 < sortedSeasons.count, let firstEp = sortedSeasons[sIdx + 1].episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }).first {
                    return (firstEp, sortedSeasons[sIdx + 1].seasonNumber)
                }
            }
        }
        return nil
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
        
        #if DEBUG
        print("[Memory] Warning received - evicted caches, kept \(keepCount) per type")
        #endif
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
            hasLoadedOnce = true
            isContentReady = true
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
        }
        
        hasLoadedOnce = true
        isLoading = false
        isLoadingInProgress = false
        
        if hasContent {
            #if os(tvOS)
            async let trending: Void = loadTrendingContent()
            async let featured: Void = loadFeaturedContent()
            _ = await (trending, featured)
            
            // Await actual image downloads for home screen content
            var homeImageURLs: [URL] = []
            homeImageURLs.append(contentsOf: trendingMovies.compactMap(\.posterURL))
            homeImageURLs.append(contentsOf: trendingShows.compactMap(\.posterURL))
            homeImageURLs.append(contentsOf: trendingChannels.compactMap(\.logoURL))
            homeImageURLs.append(contentsOf: featuredMovies.compactMap(\.posterURL))
            homeImageURLs.append(contentsOf: featuredChannels.compactMap(\.logoURL))
            
            if !homeImageURLs.isEmpty {
                NSLog("[Preload] Awaiting %d home screen images...", homeImageURLs.count)
                await ImageCacheManager.shared.prefetchAndWait(urls: homeImageURLs)
                NSLog("[Preload] Home screen images ready")
            }
            
            isContentReady = true
            
            // Continue background preloading after splash dismisses
            Task { await preloadVisibleCategories() }
            #else
            isContentReady = true
            Task {
                async let trending: Void = loadTrendingContent()
                async let featured: Void = loadFeaturedContent()
                _ = await (trending, featured)
                
                await preloadVisibleCategories()
            }
            #endif
        } else {
            isContentReady = true
        }
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
            }.sorted(by: categorySortComparator)
            
            vodCategories = vod.compactMap { cat -> CategoryInfo? in
                guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                return CategoryInfo(id: id, name: name)
            }.sorted(by: categorySortComparator)
            
            if let series = series {
                seriesCategories = series.compactMap { cat -> CategoryInfo? in
                    guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                    return CategoryInfo(id: id, name: name)
                }.sorted(by: categorySortComparator)
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
            }.sorted(by: categorySortComparator)
            
            if let vod = vod {
                vodCategories = vod.compactMap { cat -> CategoryInfo? in
                    guard let id = cat.id, let name = cat.title else { return nil }
                    return CategoryInfo(id: id, name: name)
                }.sorted(by: categorySortComparator)
            }
            
            if let series = series {
                seriesCategories = series.compactMap { cat -> CategoryInfo? in
                    guard let id = cat.id, let name = cat.title else { return nil }
                    return CategoryInfo(id: id, name: name)
                }.sorted(by: categorySortComparator)
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
            }.sorted(by: categorySortComparator)
            
            // Group movies by category
            let movieGroups = Dictionary(grouping: content.movies) { $0.category }
            for (category, movies) in movieGroups {
                movieCache[category] = movies
                touchCacheOrder(category, order: &movieCacheOrder)
            }
            
            vodCategories = movieGroups.keys.map { name in
                CategoryInfo(id: name, name: name, itemCount: movieGroups[name]?.count)
            }.sorted(by: categorySortComparator)
            
            // Set featured from first (highest-priority) sorted category
            if let firstCat = liveCategories.first,
               let firstChannels = channelGroups[firstCat.name] {
                featuredChannels = Array(firstChannels.prefix(Self.maxFeaturedItems))
            }
            if let firstCat = vodCategories.first,
               let firstMovies = movieGroups[firstCat.name] {
                featuredMovies = Array(firstMovies.prefix(Self.maxFeaturedItems))
            }
            
            hasContent = !liveCategories.isEmpty || !vodCategories.isEmpty
            
            if let epgURLString = content.epgURL, !epgURLString.isEmpty {
                Task {
                    await EPGService.shared.loadXMLTV(from: epgURLString)
                }
            }
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Featured Content
    
    /// Loads a small subset of featured content for the home screen (parallel)
    private func loadFeaturedContent() async {
        guard let credentials = cachedCredentials else { return }
        
        await withTaskGroup(of: Void.self) { group in
            if let firstLive = liveCategories.first {
                group.addTask {
                    await self.loadChannelsForCategory(firstLive)
                }
            }
            if let firstVod = vodCategories.first {
                group.addTask {
                    await self.loadMoviesForCategory(firstVod)
                }
            }
        }
        
        if let firstLive = liveCategories.first {
            featuredChannels = Array(channelCache[firstLive.name]?.prefix(Self.maxFeaturedItems) ?? [])
        }
        if let firstVod = vodCategories.first {
            featuredMovies = Array(movieCache[firstVod.name]?.prefix(Self.maxFeaturedItems) ?? [])
        }
    }
    
    // MARK: - Trending Content
    
    /// Loads trending content with concurrent network requests.
    /// Movies, shows, and channels load in parallel; each section publishes
    /// to the UI as soon as its data is ready.
    func loadTrendingContent() async {
        guard !vodCategories.isEmpty || !seriesCategories.isEmpty || !liveCategories.isEmpty else { return }
        
        let maxTrending = 20
        #if os(tvOS)
        let categoriesToLoad = 6
        #else
        let categoriesToLoad = 3
        #endif
        
        let needsMovies = trendingMovies.isEmpty && !vodCategories.isEmpty
        let needsShows = trendingShows.isEmpty && !seriesCategories.isEmpty
        let needsChannels = trendingChannels.isEmpty && !liveCategories.isEmpty
        
        guard needsMovies || needsShows || needsChannels else { return }
        
        let vodCats = needsMovies ? Array(vodCategories.prefix(categoriesToLoad)) : []
        let seriesCats = needsShows ? Array(seriesCategories.prefix(categoriesToLoad)) : []
        let liveCats = needsChannels ? Array(liveCategories.prefix(categoriesToLoad)) : []
        
        // Fire ALL category fetches concurrently — network I/O overlaps
        await withTaskGroup(of: Void.self) { group in
            for cat in vodCats {
                group.addTask { await self.loadMoviesForCategory(cat) }
            }
            for cat in seriesCats {
                group.addTask { await self.loadShowsForCategory(cat) }
            }
            for cat in liveCats {
                group.addTask { await self.loadChannelsForCategory(cat) }
            }
            
            var publishedMovies = !needsMovies
            var publishedShows = !needsShows
            var publishedChannels = !needsChannels
            
            for await _ in group {
                if !publishedMovies && vodCats.allSatisfy({ self.movieCache[$0.name] != nil }) {
                    publishedMovies = true
                    let all = vodCats.compactMap { self.movieCache[$0.name] }.flatMap { $0 }
                    let unique = Array(Dictionary(grouping: all, by: \.id).compactMapValues(\.first).values)
                    self.trendingMovies = unique
                        .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
                        .prefix(maxTrending).map { $0 }
                    ImageCacheManager.shared.prefetch(urls: self.trendingMovies.compactMap(\.posterURL))
                }
                if !publishedShows && seriesCats.allSatisfy({ self.showCache[$0.name] != nil }) {
                    publishedShows = true
                    let all = seriesCats.compactMap { self.showCache[$0.name] }.flatMap { $0 }
                    let unique = Array(Dictionary(grouping: all, by: \.id).compactMapValues(\.first).values)
                    self.trendingShows = unique
                        .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
                        .prefix(maxTrending).map { $0 }
                    ImageCacheManager.shared.prefetch(urls: self.trendingShows.compactMap(\.posterURL))
                }
                if !publishedChannels && liveCats.allSatisfy({ self.channelCache[$0.name] != nil }) {
                    publishedChannels = true
                    self.trendingChannels = liveCats
                        .compactMap { self.channelCache[$0.name] }.flatMap { $0 }
                        .prefix(maxTrending).map { $0 }
                    ImageCacheManager.shared.prefetch(urls: self.trendingChannels.compactMap(\.logoURL))
                }
            }
        }
        
        NSLog("[ContentViewModel] Loaded trending: %d movies, %d shows, %d channels",
              trendingMovies.count, trendingShows.count, trendingChannels.count)
    }
    
    // MARK: - Preloading
    
    /// Pre-loads the first N categories of each content type so they're cached
    /// before the user scrolls to them. Runs concurrently.
    private func preloadVisibleCategories() async {
        #if os(tvOS)
        let preloadCount = 8
        #else
        let preloadCount = 5
        #endif
        
        let vodToPreload = vodCategories.prefix(preloadCount).filter { movieCache[$0.name] == nil }
        let seriesToPreload = seriesCategories.prefix(preloadCount).filter { showCache[$0.name] == nil }
        let liveToPreload = liveCategories.prefix(preloadCount).filter { channelCache[$0.name] == nil }
        
        guard !vodToPreload.isEmpty || !seriesToPreload.isEmpty || !liveToPreload.isEmpty else { return }
        
        NSLog("[Preload] Starting preload: %d vod, %d series, %d live categories",
              vodToPreload.count, seriesToPreload.count, liveToPreload.count)
        
        await withTaskGroup(of: Void.self) { group in
            for cat in vodToPreload {
                group.addTask { await self.loadMoviesForCategory(cat) }
            }
            for cat in seriesToPreload {
                group.addTask { await self.loadShowsForCategory(cat) }
            }
            for cat in liveToPreload {
                group.addTask { await self.loadChannelsForCategory(cat) }
            }
        }
        
        // Prefetch images for pre-loaded content
        let movieURLs = vodToPreload.flatMap { movieCache[$0.name] ?? [] }.compactMap(\.posterURL)
        let showURLs = seriesToPreload.flatMap { showCache[$0.name] ?? [] }.compactMap(\.posterURL)
        let channelURLs = liveToPreload.flatMap { channelCache[$0.name] ?? [] }.compactMap(\.logoURL)
        
        let allURLs = Array((movieURLs + showURLs + channelURLs).prefix(200))
        if !allURLs.isEmpty {
            ImageCacheManager.shared.prefetch(urls: allURLs, maxPixelSize: ImageCacheManager.defaultMaxPixelSize)
        }
        
        NSLog("[Preload] Completed preload")
    }
    
    /// Look-ahead: when a category at `index` loads, also trigger loading for
    /// the next few categories so they're ready by the time the user scrolls.
    func prefetchNearbyCategories(around category: CategoryInfo, in list: [CategoryInfo], contentType: String) {
        guard let idx = list.firstIndex(where: { $0.id == category.id }) else { return }
        
        let lookAhead = 3
        let endIdx = min(idx + lookAhead + 1, list.count)
        guard endIdx > idx + 1 else { return }
        
        let upcoming = Array(list[(idx + 1)..<endIdx])
        
        Task {
            for cat in upcoming {
                switch contentType {
                case "movies":
                    if movieCache[cat.name] == nil {
                        await loadMoviesForCategory(cat)
                    }
                case "shows":
                    if showCache[cat.name] == nil {
                        await loadShowsForCategory(cat)
                    }
                case "channels":
                    if channelCache[cat.name] == nil {
                        await loadChannelsForCategory(cat)
                    }
                default: break
                }
            }
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
                    channelNumber: channelNumber,
                    epgChannelId: stream.epgChannelId,
                    hasCatchup: (stream.tvArchive ?? 0) == 1,
                    catchupDays: stream.tvArchiveDuration,
                    streamId: streamId
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
            
            let logoURLs = processedChannels.prefix(PlatformMetrics.rowItemLimit + 5).compactMap(\.logoURL)
            if !logoURLs.isEmpty {
                ImageCacheManager.shared.prefetch(urls: logoURLs, maxPixelSize: ImageCacheManager.defaultMaxPixelSize)
            }
            
            Task {
                await EPGService.shared.fetchBatchEPG(
                    for: processedChannels,
                    baseURL: credentials.baseURL,
                    username: credentials.username,
                    password: credentials.password
                )
            }
            
        } catch {
            #if DEBUG
            print("Failed to load channels for category \(category.name): \(error)")
            #endif
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
            #if DEBUG
            print("Failed to load Stalker channels for \(category.name): \(error)")
            #endif
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
                
                let posterURL = stream.bestImageURL.flatMap { URL(string: $0) }
                let rating = stream.rating.flatMap { Double($0) }
                return Movie(
                    id: "\(streamId)",
                    title: name,
                    posterURL: posterURL,
                    streamURL: streamURL,
                    category: category.name,
                    rating: rating,
                    streamId: streamId
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
            
            let posterURLs = processedMovies.prefix(PlatformMetrics.posterRowItemLimit + 5).compactMap(\.posterURL)
            if !posterURLs.isEmpty {
                ImageCacheManager.shared.prefetch(urls: posterURLs, maxPixelSize: ImageCacheManager.defaultMaxPixelSize)
            }
            
        } catch {
            #if DEBUG
            print("Failed to load movies for category \(category.name): \(error)")
            #endif
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
            
            let posterURLs = processedShows.prefix(PlatformMetrics.posterRowItemLimit + 5).compactMap(\.posterURL)
            if !posterURLs.isEmpty {
                ImageCacheManager.shared.prefetch(urls: posterURLs, maxPixelSize: ImageCacheManager.defaultMaxPixelSize)
            }
            
        } catch {
            #if DEBUG
            print("Failed to load shows for category \(category.name): \(error)")
            #endif
        }
        
        loadingCategoryIds.remove(category.id)
        isLoadingCategory = !loadingCategoryIds.isEmpty
    }
    
    /// Loads full series info (seasons & episodes) for a specific show.
    /// Returns an updated Show with populated seasons, or nil on failure.
    func loadSeriesInfo(for show: Show) async -> Show? {
        guard currentPlaylistType != .m3u,
              let credentials = cachedCredentials,
              let seriesId = Int(show.id) else { return nil }
        
        do {
            let seriesInfo = try await xtreamService.getSeriesInfo(
                baseURL: credentials.baseURL,
                username: credentials.username,
                password: credentials.password,
                seriesId: seriesId
            )
            
            var seasons: [Season] = []
            if let episodesDict = seriesInfo.episodes {
                for (seasonKey, episodeInfos) in episodesDict.sorted(by: { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }) {
                    let seasonNum = Int(seasonKey) ?? 0
                    let seasonInfo = seriesInfo.seasons?.first(where: { $0.seasonNumber == seasonNum })
                    
                    let episodes: [Episode] = episodeInfos.compactMap { epInfo in
                        guard let epId = epInfo.id,
                              let ext = epInfo.containerExtension,
                              let streamURL = xtreamService.buildSeriesStreamURL(
                                baseURL: credentials.baseURL,
                                username: credentials.username,
                                password: credentials.password,
                                episodeId: epId,
                                extension: ext
                              ) else { return nil }
                        
                        let thumbURL = epInfo.info?.movieImage.flatMap { URL(string: $0) }
                        let durationMinutes = epInfo.info?.duration.flatMap { durationStr -> Int? in
                            let parts = durationStr.split(separator: ":")
                            if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                                return h * 60 + m
                            }
                            return Int(durationStr)
                        }
                        
                        var episode = Episode(
                            id: epId,
                            episodeNumber: epInfo.episodeNum ?? 0,
                            title: epInfo.title ?? "Episode \(epInfo.episodeNum ?? 0)",
                            thumbnailURL: thumbURL,
                            streamURL: streamURL,
                            duration: durationMinutes,
                            description: epInfo.info?.plot
                        )
                        episode.watchProgress = storage.getWatchProgress(for: epId)
                        return episode
                    }
                    
                    let season = Season(
                        id: "\(show.id)_s\(seasonNum)",
                        seasonNumber: seasonNum,
                        title: seasonInfo?.name,
                        posterURL: seasonInfo?.cover.flatMap { URL(string: $0) },
                        episodes: episodes
                    )
                    seasons.append(season)
                }
            }
            
            let info = seriesInfo.info
            let updatedDescription = info?.plot ?? show.description
            let updatedRating: Double? = {
                if let r = show.rating { return r }
                if let rStr = info?.rating, let r = Double(rStr) { return r }
                return nil
            }()
            
            let updatedShow = Show(
                id: show.id,
                title: show.title,
                posterURL: show.posterURL,
                category: show.category,
                year: show.year,
                description: updatedDescription,
                rating: updatedRating,
                cast: info?.cast ?? show.cast,
                director: info?.director ?? show.director,
                genre: info?.genre ?? show.genre,
                seasons: seasons,
                isFavorite: show.isFavorite
            )
            
            // Update the cache so the show persists across navigations
            for (categoryName, var cachedShows) in showCache {
                if let index = cachedShows.firstIndex(where: { $0.id == show.id }) {
                    cachedShows[index] = updatedShow
                    showCache[categoryName] = cachedShows
                }
            }
            
            return updatedShow
        } catch {
            #if DEBUG
            print("Failed to load series info for \(show.title): \(error)")
            #endif
            return nil
        }
    }
    
    /// Loads detailed movie info (plot, cast, director, genre) from Xtream Codes API.
    /// Returns an updated Movie with populated fields, or nil on failure.
    func loadMovieInfo(for movie: Movie) async -> Movie? {
        guard currentPlaylistType != .m3u,
              let credentials = cachedCredentials,
              let vodId = movie.streamId else { return nil }
        
        do {
            let vodInfo = try await xtreamService.getVodInfo(
                baseURL: credentials.baseURL,
                username: credentials.username,
                password: credentials.password,
                vodId: vodId
            )
            
            guard let info = vodInfo.info else { return nil }
            
            var durationMinutes: Int? = movie.duration
            if durationMinutes == nil, let durStr = info.duration {
                let parts = durStr.split(separator: ":")
                if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                    durationMinutes = h * 60 + m
                } else if let mins = Int(durStr) {
                    durationMinutes = mins
                }
            }
            
            var rating: Double? = movie.rating
            if rating == nil, let ratingStr = info.rating, let r = Double(ratingStr) {
                rating = r
            }
            
            var year: Int? = movie.year
            if year == nil, let releaseDate = info.releaseDate {
                let parts = releaseDate.split(separator: "-")
                if let first = parts.first, let y = Int(first) {
                    year = y
                }
            }
            
            let backdropURL = info.backdrop.flatMap { URL(string: $0) }
            let posterURL = info.movieImage.flatMap { URL(string: $0) } ?? movie.posterURL
            
            let updatedMovie = Movie(
                id: movie.id,
                title: movie.title,
                posterURL: posterURL,
                streamURL: movie.streamURL,
                category: movie.category,
                year: year,
                duration: durationMinutes,
                description: info.plot ?? movie.description,
                rating: rating,
                director: info.director,
                cast: info.cast,
                genre: info.genre,
                backdropURL: backdropURL,
                streamId: movie.streamId,
                isFavorite: movie.isFavorite,
                watchProgress: movie.watchProgress,
                isDetailLoaded: true
            )
            
            // Update cache
            for (categoryName, var cachedMovies) in movieCache {
                if let index = cachedMovies.firstIndex(where: { $0.id == movie.id }) {
                    cachedMovies[index] = updatedMovie
                    movieCache[categoryName] = cachedMovies
                }
            }
            
            return updatedMovie
        } catch {
            NSLog("[ContentViewModel] Failed to load VOD info for %@: %@", movie.title, error.localizedDescription)
            return nil
        }
    }
    
    /// Gets priority for category sorting (lower = shown first, higher = shown last)
    private func categoryPriority(_ category: String) -> Int {
        languagePriorityConfig.priority(for: category)
    }
    
    /// Re-sorts all category arrays based on current language priority
    private func resortCategories() {
        liveCategories = liveCategories.sorted(by: categorySortComparator)
        vodCategories = vodCategories.sorted(by: categorySortComparator)
        seriesCategories = seriesCategories.sorted(by: categorySortComparator)
        
        #if DEBUG
        logSortedCategories("Live", liveCategories)
        logSortedCategories("VOD", vodCategories)
        logSortedCategories("Series", seriesCategories)
        #endif
    }
    
    private func categorySortComparator(_ a: CategoryInfo, _ b: CategoryInfo) -> Bool {
        let pa = categoryPriority(a.name)
        let pb = categoryPriority(b.name)
        if pa != pb { return pa < pb }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
    
    #if DEBUG
    private func logSortedCategories(_ label: String, _ cats: [CategoryInfo]) {
        guard !cats.isEmpty else { return }
        NSLog("[Priority] --- %@ categories (%d) ---", label, cats.count)
        for (i, cat) in cats.prefix(15).enumerated() {
            let lang = IPTVLanguage.detect(from: cat.name)?.displayName ?? "undetected"
            let pri = categoryPriority(cat.name)
            NSLog("[Priority] %d. \"%@\" → lang=%@ pri=%d", i, cat.name, lang, pri)
        }
        if cats.count > 15 {
            NSLog("[Priority] ... and %d more", cats.count - 15)
        }
    }
    #endif
    
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
        guard !hasLoadedOnce else { return }
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
    
    #if DEBUG
    func setCachesForTesting(channelCache: [String: [Channel]] = [:],
                             movieCache: [String: [Movie]] = [:],
                             showCache: [String: [Show]] = [:]) {
        self.channelCache = channelCache
        self.movieCache = movieCache
        self.showCache = showCache
    }
    #endif
    
    func buildArchiveURL(for channel: Channel, program: EPGProgram) -> URL? {
        guard let credentials = cachedCredentials,
              let streamId = channel.streamId else { return nil }
        let durationMinutes = Int(program.end.timeIntervalSince(program.start) / 60)
        return xtreamService.buildArchiveURL(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password,
            streamId: streamId,
            start: program.start,
            durationMinutes: durationMinutes
        )
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
