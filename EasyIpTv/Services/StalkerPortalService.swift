import Foundation

/// Service for Stalker Portal / Ministra API (MAC-based IPTV)
actor StalkerPortalService {
    
    // MARK: - Errors
    
    enum StalkerError: Error, LocalizedError {
        case invalidURL
        case handshakeFailed
        case authenticationFailed
        case networkError(Error)
        case decodingError(Error)
        case invalidMACAddress
        case noToken
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid Stalker Portal URL"
            case .handshakeFailed: return "Handshake with portal failed"
            case .authenticationFailed: return "MAC address authentication failed"
            case .networkError(let error): return "Network error: \(error.localizedDescription)"
            case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
            case .invalidMACAddress: return "Invalid MAC address format"
            case .noToken: return "No authentication token available"
            }
        }
    }
    
    // MARK: - Response Models
    
    struct HandshakeResponse: Codable {
        let js: TokenData?
        
        struct TokenData: Codable {
            let token: String?
        }
    }
    
    struct CategoryResponse: Codable {
        let js: [Category]?
        
        struct Category: Codable {
            let id: String?
            let title: String?
            let alias: String?
            let censored: String?
            
            // Some portals use different key names
            private enum CodingKeys: String, CodingKey {
                case id, title, alias, censored
            }
        }
    }
    
    struct ChannelListResponse: Codable {
        let js: ChannelData?
        
        struct ChannelData: Codable {
            let totalItems: Int?
            let maxPageItems: Int?
            let data: [ChannelItem]?
            
            private enum CodingKeys: String, CodingKey {
                case totalItems = "total_items"
                case maxPageItems = "max_page_items"
                case data
            }
        }
    }
    
    struct ChannelItem: Codable {
        let id: String?
        let name: String?
        let number: Int?
        let cmd: String?
        let logo: String?
        let categoryId: String?
        
        private enum CodingKeys: String, CodingKey {
            case id, name, number, cmd, logo
            case categoryId = "tv_genre_id"
        }
    }
    
    struct VODListResponse: Codable {
        let js: VODData?
        
        struct VODData: Codable {
            let totalItems: Int?
            let maxPageItems: Int?
            let data: [VODItem]?
            
            private enum CodingKeys: String, CodingKey {
                case totalItems = "total_items"
                case maxPageItems = "max_page_items"
                case data
            }
        }
    }
    
    struct VODItem: Codable {
        let id: String?
        let name: String?
        let cmd: String?
        let logo: String?
        let description: String?
        let year: String?
        let categoryId: String?
        
        private enum CodingKeys: String, CodingKey {
            case id, name, cmd, logo, description, year
            case categoryId = "category_id"
        }
    }
    
    struct SeriesListResponse: Codable {
        let js: SeriesData?
        
        struct SeriesData: Codable {
            let totalItems: Int?
            let maxPageItems: Int?
            let data: [SeriesItem]?
            
            private enum CodingKeys: String, CodingKey {
                case totalItems = "total_items"
                case maxPageItems = "max_page_items"
                case data
            }
        }
    }
    
    struct SeriesItem: Codable {
        let id: String?
        let name: String?
        let cmd: String?
        let logo: String?
        let description: String?
        let year: String?
        let categoryId: String?
        
        private enum CodingKeys: String, CodingKey {
            case id, name, cmd, logo, description, year
            case categoryId = "category_id"
        }
    }
    
    // MARK: - Properties
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()
    
    private let decoder = JSONDecoder()
    private var currentToken: String?
    
    // MARK: - URL Detection
    
    /// Checks if a URL is a Stalker Portal URL (uses stalker:// scheme)
    static func isStalkerPortalURL(_ url: URL) -> Bool {
        return url.scheme == "stalker"
    }
    
    /// Extracts portal URL and MAC address from a stalker:// URL
    /// Format: stalker://host:port/path?mac=XX:XX:XX:XX:XX:XX
    static func extractCredentials(from url: URL) -> (portalURL: String, macAddress: String)? {
        guard url.scheme == "stalker" else { return nil }
        
        // Reconstruct HTTP URL from stalker:// scheme
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "http"
        
        guard let macValue = components?.queryItems?.first(where: { $0.name == "mac" })?.value else {
            return nil
        }
        
        // Remove mac query param to get clean portal URL
        components?.queryItems = nil
        guard let portalURL = components?.url?.absoluteString else { return nil }
        
        return (portalURL, macValue)
    }
    
    /// Builds a stalker:// URL from portal URL and MAC address
    static func buildStalkerURL(portalURL: String, macAddress: String) -> URL? {
        guard var components = URLComponents(string: portalURL) else { return nil }
        components.scheme = "stalker"
        components.queryItems = [URLQueryItem(name: "mac", value: macAddress)]
        return components.url
    }
    
    /// Validates MAC address format (XX:XX:XX:XX:XX:XX)
    static func isValidMACAddress(_ mac: String) -> Bool {
        let pattern = #"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"#
        return mac.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Extracts the stream URL from a Stalker Portal cmd field
    /// Format: "ffmpeg http://server.com/stream" or "http://server.com/stream"
    static func extractStreamURL(from cmd: String) -> URL? {
        let cleaned = cmd
            .replacingOccurrences(of: "ffmpeg ", with: "")
            .replacingOccurrences(of: "ffrt ", with: "")
            .trimmingCharacters(in: .whitespaces)
        return URL(string: cleaned)
    }
    
    // MARK: - Authentication
    
    /// Performs handshake and authentication with the portal
    func authenticate(portalURL: String, macAddress: String) async throws -> String {
        guard Self.isValidMACAddress(macAddress) else {
            throw StalkerError.invalidMACAddress
        }
        
        // Step 1: Handshake to get token
        let token = try await handshake(portalURL: portalURL, macAddress: macAddress)
        currentToken = token
        
        // Step 2: Get profile to validate MAC
        try await getProfile(portalURL: portalURL, macAddress: macAddress, token: token)
        
        return token
    }
    
    /// Performs handshake to obtain session token
    private func handshake(portalURL: String, macAddress: String) async throws -> String {
        let urlString = "\(portalURL)/portal.php?type=stb&action=handshake&prehash=false&token=&JsHttpRequest=1-xml"
        guard let url = URL(string: urlString) else {
            throw StalkerError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(macCookie(macAddress), forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (QtEmbedded; U; Linux; C)", forHTTPHeaderField: "User-Agent")
        
        let data = try await fetchData(request: request)
        
        do {
            let response = try decoder.decode(HandshakeResponse.self, from: data)
            guard let token = response.js?.token, !token.isEmpty else {
                throw StalkerError.handshakeFailed
            }
            return token
        } catch let error as StalkerError {
            throw error
        } catch {
            throw StalkerError.decodingError(error)
        }
    }
    
    /// Validates MAC by getting profile
    private func getProfile(portalURL: String, macAddress: String, token: String) async throws {
        let urlString = "\(portalURL)/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml"
        guard let url = URL(string: urlString) else {
            throw StalkerError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(macCookie(macAddress), forHTTPHeaderField: "Cookie")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (QtEmbedded; U; Linux; C)", forHTTPHeaderField: "User-Agent")
        
        // Just verify we get a valid response
        let _ = try await fetchData(request: request)
    }
    
    // MARK: - Categories
    
    /// Gets live TV categories (genres)
    func getLiveCategories(portalURL: String, macAddress: String, token: String) async throws -> [CategoryResponse.Category] {
        let urlString = "\(portalURL)/portal.php?type=itv&action=get_genres&JsHttpRequest=1-xml"
        let data = try await fetchAuthenticatedData(urlString: urlString, macAddress: macAddress, token: token)
        
        let response = try decoder.decode(CategoryResponse.self, from: data)
        return response.js ?? []
    }
    
    /// Gets VOD categories
    func getVodCategories(portalURL: String, macAddress: String, token: String) async throws -> [CategoryResponse.Category] {
        let urlString = "\(portalURL)/portal.php?type=vod&action=get_categories&JsHttpRequest=1-xml"
        let data = try await fetchAuthenticatedData(urlString: urlString, macAddress: macAddress, token: token)
        
        let response = try decoder.decode(CategoryResponse.self, from: data)
        return response.js ?? []
    }
    
    /// Gets series categories
    func getSeriesCategories(portalURL: String, macAddress: String, token: String) async throws -> [CategoryResponse.Category] {
        let urlString = "\(portalURL)/portal.php?type=series&action=get_categories&JsHttpRequest=1-xml"
        let data = try await fetchAuthenticatedData(urlString: urlString, macAddress: macAddress, token: token)
        
        let response = try decoder.decode(CategoryResponse.self, from: data)
        return response.js ?? []
    }
    
    // MARK: - Content Lists
    
    /// Gets live channels for a category
    func getLiveChannels(portalURL: String, macAddress: String, token: String, categoryId: String, page: Int = 0) async throws -> [ChannelItem] {
        let urlString = "\(portalURL)/portal.php?type=itv&action=get_ordered_list&genre=\(categoryId)&force_ch_link_check=&p=\(page)&JsHttpRequest=1-xml"
        let data = try await fetchAuthenticatedData(urlString: urlString, macAddress: macAddress, token: token)
        
        let response = try decoder.decode(ChannelListResponse.self, from: data)
        return response.js?.data ?? []
    }
    
    /// Gets VOD items for a category
    func getVodItems(portalURL: String, macAddress: String, token: String, categoryId: String, page: Int = 0) async throws -> [VODItem] {
        let urlString = "\(portalURL)/portal.php?type=vod&action=get_ordered_list&category=\(categoryId)&p=\(page)&JsHttpRequest=1-xml"
        let data = try await fetchAuthenticatedData(urlString: urlString, macAddress: macAddress, token: token)
        
        let response = try decoder.decode(VODListResponse.self, from: data)
        return response.js?.data ?? []
    }
    
    /// Gets series items for a category
    func getSeriesItems(portalURL: String, macAddress: String, token: String, categoryId: String, page: Int = 0) async throws -> [SeriesItem] {
        let urlString = "\(portalURL)/portal.php?type=series&action=get_ordered_list&category=\(categoryId)&p=\(page)&JsHttpRequest=1-xml"
        let data = try await fetchAuthenticatedData(urlString: urlString, macAddress: macAddress, token: token)
        
        let response = try decoder.decode(SeriesListResponse.self, from: data)
        return response.js?.data ?? []
    }
    
    // MARK: - Stream URL Resolution
    
    /// Gets the actual stream URL for a channel (some portals require a separate request)
    func getStreamURL(portalURL: String, macAddress: String, token: String, cmd: String, type: String = "itv") async throws -> URL? {
        let encodedCmd = cmd.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cmd
        let urlString = "\(portalURL)/portal.php?type=\(type)&action=create_link&cmd=\(encodedCmd)&JsHttpRequest=1-xml"
        
        let data = try await fetchAuthenticatedData(urlString: urlString, macAddress: macAddress, token: token)
        
        // Response contains the actual stream URL
        struct LinkResponse: Codable {
            let js: LinkData?
            struct LinkData: Codable {
                let cmd: String?
            }
        }
        
        if let response = try? decoder.decode(LinkResponse.self, from: data),
           let resolvedCmd = response.js?.cmd {
            return Self.extractStreamURL(from: resolvedCmd)
        }
        
        // Fallback: extract from original cmd
        return Self.extractStreamURL(from: cmd)
    }
    
    // MARK: - Private Helpers
    
    private func fetchAuthenticatedData(urlString: String, macAddress: String, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw StalkerError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(macCookie(macAddress), forHTTPHeaderField: "Cookie")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (QtEmbedded; U; Linux; C)", forHTTPHeaderField: "User-Agent")
        
        return try await fetchData(request: request)
    }
    
    private func fetchData(request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw StalkerError.networkError(
                    NSError(domain: "HTTP", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                )
            }
            
            return data
        } catch let error as StalkerError {
            throw error
        } catch {
            throw StalkerError.networkError(error)
        }
    }
    
    private func macCookie(_ mac: String) -> String {
        "mac=\(mac.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mac); stb_lang=en; timezone=Europe%2FLondon"
    }
}
