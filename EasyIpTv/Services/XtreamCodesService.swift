import Foundation

/// Service for Xtream Codes API
actor XtreamCodesService {
    
    /// Optimized URLSession for fast API calls
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15 // Reduced from 30
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 6 // Increase concurrent connections
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil // Don't cache API responses (we cache data ourselves)
        config.httpShouldUsePipelining = true
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        return URLSession(configuration: config)
    }()
    
    /// Errors that can occur
    enum XtreamError: Error, LocalizedError {
        case invalidURL
        case authenticationFailed
        case networkError(Error)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Xtream Codes URL"
            case .authenticationFailed:
                return "Authentication failed"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - API Response Models
    
    struct AuthResponse: Codable {
        let userInfo: UserInfo?
        let serverInfo: ServerInfo?
        
        enum CodingKeys: String, CodingKey {
            case userInfo = "user_info"
            case serverInfo = "server_info"
        }
    }
    
    struct UserInfo: Codable {
        let username: String?
        let password: String?
        let auth: Int?
        let status: String?
        let expDate: String?
        let maxConnections: String?
        
        enum CodingKeys: String, CodingKey {
            case username, password, auth, status
            case expDate = "exp_date"
            case maxConnections = "max_connections"
        }
    }
    
    struct ServerInfo: Codable {
        let url: String?
        let port: String?
        let httpsPort: String?
        let serverProtocol: String?
        
        enum CodingKeys: String, CodingKey {
            case url, port
            case httpsPort = "https_port"
            case serverProtocol = "server_protocol"
        }
    }
    
    struct LiveStream: Codable {
        let num: Int?
        let name: String?
        let streamType: String?
        let streamId: Int?
        let streamIcon: String?
        let categoryId: String?
        let epgChannelId: String?
        let isAdult: Int?
        let tvArchive: Int?
        let tvArchiveDuration: Int?
        
        enum CodingKeys: String, CodingKey {
            case num, name
            case streamType = "stream_type"
            case streamId = "stream_id"
            case streamIcon = "stream_icon"
            case categoryId = "category_id"
            case epgChannelId = "epg_channel_id"
            case isAdult = "is_adult"
            case tvArchive = "tv_archive"
            case tvArchiveDuration = "tv_archive_duration"
        }
    }
    
    struct EPGItem: Codable {
        let id: String?
        let epgId: String?
        let title: String?
        let lang: String?
        let start: String?
        let end: String?
        let description: String?
        let channelId: String?
        
        enum CodingKeys: String, CodingKey {
            case id, title, lang, start, end, description
            case epgId = "epg_id"
            case channelId = "channel_id"
        }
    }
    
    struct ShortEPGResponse: Codable {
        let epgListings: [EPGItem]?
        
        enum CodingKeys: String, CodingKey {
            case epgListings = "epg_listings"
        }
    }
    
    struct LiveCategory: Codable {
        let categoryId: String?
        let categoryName: String?
        
        enum CodingKeys: String, CodingKey {
            case categoryId = "category_id"
            case categoryName = "category_name"
        }
    }
    
    struct VodStream: Codable {
        let num: Int?
        let name: String?
        let streamType: String?
        let streamId: Int?
        let streamIcon: String?
        let categoryId: String?
        let containerExtension: String?
        let rating: String?
        let coverBig: String?
        
        enum CodingKeys: String, CodingKey {
            case num, name, rating
            case streamType = "stream_type"
            case streamId = "stream_id"
            case streamIcon = "stream_icon"
            case categoryId = "category_id"
            case containerExtension = "container_extension"
            case coverBig = "cover_big"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            num = try container.decodeIfPresent(Int.self, forKey: .num)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            streamType = try container.decodeIfPresent(String.self, forKey: .streamType)
            streamId = try container.decodeIfPresent(Int.self, forKey: .streamId)
            streamIcon = try container.decodeIfPresent(String.self, forKey: .streamIcon)
            categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
            containerExtension = try container.decodeIfPresent(String.self, forKey: .containerExtension)
            coverBig = try container.decodeIfPresent(String.self, forKey: .coverBig)
            if let ratingStr = try? container.decodeIfPresent(String.self, forKey: .rating) {
                rating = ratingStr
            } else if let ratingNum = try? container.decodeIfPresent(Double.self, forKey: .rating) {
                rating = String(ratingNum)
            } else {
                rating = nil
            }
        }
        
        var bestImageURL: String? {
            if let icon = streamIcon, !icon.isEmpty { return icon }
            if let cover = coverBig, !cover.isEmpty { return cover }
            return nil
        }
    }
    
    struct Series: Codable {
        let num: Int?
        let name: String?
        let seriesId: Int?
        let cover: String?
        let categoryId: String?
        let plot: String?
        let cast: String?
        let director: String?
        let genre: String?
        let releaseDate: String?
        let rating: String?
        
        enum CodingKeys: String, CodingKey {
            case num, name, cover, plot, cast, director, genre, rating
            case seriesId = "series_id"
            case categoryId = "category_id"
            case releaseDate = "release_date"
        }
        
        // Custom init to handle flexible decoding
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            num = try container.decodeIfPresent(Int.self, forKey: .num)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            seriesId = try container.decodeIfPresent(Int.self, forKey: .seriesId)
            cover = try container.decodeIfPresent(String.self, forKey: .cover)
            categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
            plot = try container.decodeIfPresent(String.self, forKey: .plot)
            cast = try container.decodeIfPresent(String.self, forKey: .cast)
            director = try container.decodeIfPresent(String.self, forKey: .director)
            genre = try container.decodeIfPresent(String.self, forKey: .genre)
            releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
            // Rating can be either String or number in JSON
            if let ratingStr = try? container.decodeIfPresent(String.self, forKey: .rating) {
                rating = ratingStr
            } else if let ratingNum = try? container.decodeIfPresent(Double.self, forKey: .rating) {
                rating = String(ratingNum)
            } else {
                rating = nil
            }
        }
    }
    
    struct SeriesInfo: Codable {
        let seasons: [SeasonInfo]?
        let info: SeriesDetails?
        let episodes: [String: [EpisodeInfo]]?
    }
    
    struct SeriesDetails: Codable {
        let name: String?
        let cover: String?
        let plot: String?
        let cast: String?
        let director: String?
        let genre: String?
        let releaseDate: String?
        let rating: String?
        let categoryId: String?
        
        enum CodingKeys: String, CodingKey {
            case name, cover, plot, cast, director, genre, rating
            case releaseDate = "releaseDate"
            case categoryId = "category_id"
        }
    }
    
    struct SeasonInfo: Codable {
        let seasonNumber: Int?
        let name: String?
        let episodeCount: Int?
        let cover: String?
        
        enum CodingKeys: String, CodingKey {
            case name, cover
            case seasonNumber = "season_number"
            case episodeCount = "episode_count"
        }
    }
    
    struct EpisodeInfo: Codable {
        let id: String?
        let episodeNum: Int?
        let title: String?
        let containerExtension: String?
        let info: EpisodeDetails?
        let customSid: String?
        let directSource: String?
        
        enum CodingKeys: String, CodingKey {
            case id, title, info
            case episodeNum = "episode_num"
            case containerExtension = "container_extension"
            case customSid = "custom_sid"
            case directSource = "direct_source"
        }
    }
    
    struct EpisodeDetails: Codable {
        let movieImage: String?
        let plot: String?
        let duration: String?
        let rating: Double?
        let name: String?
        
        enum CodingKeys: String, CodingKey {
            case plot, duration, name
            case movieImage = "movie_image"
            case rating
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            movieImage = try container.decodeIfPresent(String.self, forKey: .movieImage)
            plot = try container.decodeIfPresent(String.self, forKey: .plot)
            duration = try container.decodeIfPresent(String.self, forKey: .duration)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            if let d = try? container.decodeIfPresent(Double.self, forKey: .rating) {
                rating = d
            } else if let s = try? container.decodeIfPresent(String.self, forKey: .rating) {
                rating = Double(s)
            } else {
                rating = nil
            }
        }
    }
    
    // MARK: - Properties
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
    
    // MARK: - Public Methods
    
    /// Checks if a URL is an Xtream Codes URL
    static func isXtreamCodesURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        // Check for common Xtream Codes URL patterns
        return urlString.contains("get.php") && 
               urlString.contains("username=") && 
               urlString.contains("password=")
    }
    
    /// Extracts credentials from an Xtream Codes URL
    static func extractCredentials(from url: URL) -> (baseURL: String, username: String, password: String)? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return nil
        }
        
        let scheme = components.scheme ?? "http"
        let port = components.port.map { ":\($0)" } ?? ""
        let baseURL = "\(scheme)://\(host)\(port)"
        
        var username: String?
        var password: String?
        
        for item in components.queryItems ?? [] {
            if item.name == "username" {
                username = item.value
            } else if item.name == "password" {
                password = item.value
            }
        }
        
        guard let user = username, let pass = password else {
            return nil
        }
        
        return (baseURL, user, pass)
    }
    
    /// Authenticates with the Xtream Codes server
    func authenticate(baseURL: String, username: String, password: String) async throws -> AuthResponse {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            let response = try decoder.decode(AuthResponse.self, from: data)
            guard response.userInfo?.auth == 1 else {
                throw XtreamError.authenticationFailed
            }
            return response
        } catch let error as XtreamError {
            throw error
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets live categories
    func getLiveCategories(baseURL: String, username: String, password: String) async throws -> [LiveCategory] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_live_categories"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([LiveCategory].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets live streams
    func getLiveStreams(baseURL: String, username: String, password: String) async throws -> [LiveStream] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_live_streams"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([LiveStream].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets VOD categories
    func getVodCategories(baseURL: String, username: String, password: String) async throws -> [LiveCategory] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_vod_categories"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([LiveCategory].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets VOD streams (movies)
    func getVodStreams(baseURL: String, username: String, password: String) async throws -> [VodStream] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_vod_streams"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([VodStream].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets series
    func getSeries(baseURL: String, username: String, password: String) async throws -> [Series] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_series"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([Series].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets series categories
    func getSeriesCategories(baseURL: String, username: String, password: String) async throws -> [LiveCategory] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_series_categories"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([LiveCategory].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    // MARK: - VOD Info
    
    struct VodInfo: Codable {
        let info: VodDetails?
        let movieData: VodMovieData?
        
        enum CodingKeys: String, CodingKey {
            case info
            case movieData = "movie_data"
        }
    }
    
    struct VodDetails: Codable {
        let movieImage: String?
        let plot: String?
        let cast: String?
        let director: String?
        let genre: String?
        let releaseDate: String?
        let duration: String?
        let rating: String?
        let name: String?
        let backdrop: String?
        let tmdbId: String?
        
        enum CodingKeys: String, CodingKey {
            case plot, cast, director, genre, duration, rating, name, backdrop
            case movieImage = "movie_image"
            case releaseDate = "releasedate"
            case tmdbId = "tmdb_id"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            movieImage = try container.decodeIfPresent(String.self, forKey: .movieImage)
            plot = try container.decodeIfPresent(String.self, forKey: .plot)
            cast = try container.decodeIfPresent(String.self, forKey: .cast)
            director = try container.decodeIfPresent(String.self, forKey: .director)
            genre = try container.decodeIfPresent(String.self, forKey: .genre)
            releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
            duration = try container.decodeIfPresent(String.self, forKey: .duration)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            backdrop = try container.decodeIfPresent(String.self, forKey: .backdrop)
            tmdbId = try container.decodeIfPresent(String.self, forKey: .tmdbId)
            if let ratingStr = try? container.decodeIfPresent(String.self, forKey: .rating) {
                rating = ratingStr
            } else if let ratingNum = try? container.decodeIfPresent(Double.self, forKey: .rating) {
                rating = String(ratingNum)
            } else {
                rating = nil
            }
        }
    }
    
    struct VodMovieData: Codable {
        let streamId: Int?
        let name: String?
        let containerExtension: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case streamId = "stream_id"
            case containerExtension = "container_extension"
        }
    }
    
    /// Gets detailed VOD (movie) info
    func getVodInfo(baseURL: String, username: String, password: String, vodId: Int) async throws -> VodInfo {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_vod_info&vod_id=\(vodId)"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode(VodInfo.self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets detailed series info including episodes
    func getSeriesInfo(baseURL: String, username: String, password: String, seriesId: Int) async throws -> SeriesInfo {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_series_info&series_id=\(seriesId)"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode(SeriesInfo.self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Builds the stream URL for a series episode
    nonisolated func buildSeriesStreamURL(baseURL: String, username: String, password: String, episodeId: String, extension ext: String) -> URL? {
        let urlString = "\(baseURL)/series/\(username)/\(password)/\(episodeId).\(ext)"
        return URL(string: urlString)
    }
    
    /// Builds the stream URL for a live channel
    nonisolated func buildLiveStreamURL(baseURL: String, username: String, password: String, streamId: Int) -> URL? {
        let urlString = "\(baseURL)/live/\(username)/\(password)/\(streamId).m3u8"
        return URL(string: urlString)
    }
    
    /// Builds the stream URL for a VOD movie
    nonisolated func buildVodStreamURL(baseURL: String, username: String, password: String, streamId: Int, extension ext: String) -> URL? {
        let urlString = "\(baseURL)/movie/\(username)/\(password)/\(streamId).\(ext)"
        return URL(string: urlString)
    }
    
    // MARK: - EPG
    
    func getShortEPG(baseURL: String, username: String, password: String, streamId: Int) async throws -> [EPGProgram] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_short_epg&stream_id=\(streamId)"
        guard let url = URL(string: urlString) else { throw XtreamError.invalidURL }
        let data = try await fetchData(from: url)
        let response = try decoder.decode(ShortEPGResponse.self, from: data)
        return (response.epgListings ?? []).compactMap { Self.mapEPGItem($0) }
    }
    
    func getFullEPG(baseURL: String, username: String, password: String, streamId: Int) async throws -> [EPGProgram] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_simple_data_table&stream_id=\(streamId)"
        guard let url = URL(string: urlString) else { throw XtreamError.invalidURL }
        let data = try await fetchData(from: url)
        let response = try decoder.decode(ShortEPGResponse.self, from: data)
        return (response.epgListings ?? []).compactMap { Self.mapEPGItem($0) }
    }
    
    private static let epgDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
    
    nonisolated static func mapEPGItem(_ item: EPGItem) -> EPGProgram? {
        guard let title = item.title,
              let startStr = item.start,
              let endStr = item.end,
              let start = epgDateFormatter.date(from: startStr),
              let end = epgDateFormatter.date(from: endStr) else { return nil }
        
        let decodedTitle = Self.decodeBase64IfNeeded(title)
        let decodedDesc = item.description.flatMap { Self.decodeBase64IfNeeded($0) }
        
        return EPGProgram(
            id: item.id ?? UUID().uuidString,
            title: decodedTitle,
            description: decodedDesc,
            start: start,
            end: end,
            channelId: item.channelId ?? item.epgId ?? "",
            lang: item.lang
        )
    }
    
    nonisolated private static func decodeBase64IfNeeded(_ string: String) -> String {
        guard let data = Data(base64Encoded: string),
              let decoded = String(data: data, encoding: .utf8) else {
            return string
        }
        return decoded
    }
    
    // MARK: - TV Archive / Catchup
    
    nonisolated func buildArchiveURL(baseURL: String, username: String, password: String, streamId: Int, start: Date, durationMinutes: Int) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd:HH-mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let startStr = formatter.string(from: start)
        let urlString = "\(baseURL)/streaming/timeshift.php?username=\(username)&password=\(password)&stream=\(streamId)&start=\(startStr)&duration=\(durationMinutes)"
        return URL(string: urlString)
    }
    
    // MARK: - Category-Specific Loading (Pagination)
    
    /// Gets live streams for a specific category
    func getLiveStreamsByCategory(baseURL: String, username: String, password: String, categoryId: String) async throws -> [LiveStream] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_live_streams&category_id=\(categoryId)"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([LiveStream].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets VOD streams for a specific category
    func getVodStreamsByCategory(baseURL: String, username: String, password: String, categoryId: String) async throws -> [VodStream] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_vod_streams&category_id=\(categoryId)"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([VodStream].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    /// Gets series for a specific category
    func getSeriesByCategory(baseURL: String, username: String, password: String, categoryId: String) async throws -> [Series] {
        let urlString = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_series&category_id=\(categoryId)"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        let data = try await fetchData(from: url)
        
        do {
            return try decoder.decode([Series].self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        do {
            let (data, _) = try await session.data(for: request)
            return data
        } catch {
            throw XtreamError.networkError(error)
        }
    }
}
