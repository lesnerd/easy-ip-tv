import Foundation

/// Service for parsing M3U/M3U8 playlist files
actor M3UParser {
    
    /// Errors that can occur during parsing
    enum ParserError: Error, LocalizedError {
        case invalidFormat
        case invalidURL
        case networkError(Error)
        case emptyPlaylist
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return String(localized: "Invalid M3U format")
            case .invalidURL:
                return String(localized: "Invalid playlist URL")
            case .networkError(let error):
                return String(localized: "Network error: \(error.localizedDescription)")
            case .emptyPlaylist:
                return String(localized: "Playlist is empty")
            }
        }
    }
    
    /// Parsed result containing categorized content
    struct ParsedContent {
        var channels: [Channel]
        var movies: [Movie]
        var shows: [Show]
        var categories: [String: ContentType]
        
        static var empty: ParsedContent {
            ParsedContent(channels: [], movies: [], shows: [], categories: [:])
        }
    }
    
    // MARK: - Public Methods
    
    /// Parses an M3U playlist from a URL
    func parse(from url: URL) async throws -> ParsedContent {
        let data: Data
        
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            // Create request with proper headers for IPTV compatibility
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 30
            
            let (fetchedData, _) = try await URLSession.shared.data(for: request)
            data = fetchedData
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw ParserError.invalidFormat
        }
        
        return try parse(content: content)
    }
    
    /// Parses an M3U playlist from string content
    func parse(content: String) throws -> ParsedContent {
        let lines = content.components(separatedBy: .newlines)
        
        guard lines.first?.hasPrefix("#EXTM3U") == true else {
            throw ParserError.invalidFormat
        }
        
        var items: [M3UItem] = []
        var currentInfo: ExtInfInfo?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("#EXTINF:") {
                currentInfo = parseExtInf(line: trimmedLine)
            } else if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") {
                if let info = currentInfo, let streamURL = URL(string: trimmedLine) {
                    let item = M3UItem(
                        id: info.tvgId ?? UUID().uuidString,
                        name: info.name,
                        logoURL: info.logoURL,
                        streamURL: streamURL,
                        groupTitle: info.groupTitle ?? "Uncategorized",
                        tvgId: info.tvgId,
                        tvgName: info.tvgName,
                        duration: info.duration
                    )
                    items.append(item)
                }
                currentInfo = nil
            }
        }
        
        guard !items.isEmpty else {
            throw ParserError.emptyPlaylist
        }
        
        return categorize(items: items)
    }
    
    // MARK: - Private Methods
    
    /// Temporary structure for parsing EXTINF lines
    private struct ExtInfInfo {
        let duration: Int
        let name: String
        let tvgId: String?
        let tvgName: String?
        let tvgLogo: String?
        let groupTitle: String?
        
        var logoURL: URL? {
            guard let logo = tvgLogo else { return nil }
            return URL(string: logo)
        }
    }
    
    /// Parses an #EXTINF line
    private func parseExtInf(line: String) -> ExtInfInfo? {
        // Format: #EXTINF:-1 tvg-id="id" tvg-name="Name" tvg-logo="url" group-title="Category",Channel Name
        
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        
        let afterColon = String(line[line.index(after: colonIndex)...])
        
        // Extract duration
        var duration = -1
        if let spaceIndex = afterColon.firstIndex(of: " ") {
            let durationStr = String(afterColon[..<spaceIndex])
            duration = Int(durationStr) ?? -1
        }
        
        // Extract name (after the comma)
        var name = "Unknown"
        if let commaIndex = afterColon.lastIndex(of: ",") {
            name = String(afterColon[afterColon.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        
        // Extract attributes using regex
        let tvgId = extractAttribute(from: line, attribute: "tvg-id")
        let tvgName = extractAttribute(from: line, attribute: "tvg-name")
        let tvgLogo = extractAttribute(from: line, attribute: "tvg-logo")
        let groupTitle = extractAttribute(from: line, attribute: "group-title")
        
        return ExtInfInfo(
            duration: duration,
            name: name,
            tvgId: tvgId,
            tvgName: tvgName,
            tvgLogo: tvgLogo,
            groupTitle: groupTitle
        )
    }
    
    /// Extracts an attribute value from an EXTINF line
    private func extractAttribute(from line: String, attribute: String) -> String? {
        let pattern = "\(attribute)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        
        return String(line[valueRange])
    }
    
    /// Categorizes M3U items into channels, movies, and shows
    private func categorize(items: [M3UItem]) -> ParsedContent {
        var channels: [Channel] = []
        var movies: [Movie] = []
        var showsDict: [String: Show] = [:] // Group by show title
        var categories: [String: ContentType] = [:]
        
        var channelNumber = 1
        
        for item in items {
            let contentType = item.inferredContentType
            categories[item.groupTitle] = contentType
            
            switch contentType {
            case .liveTV:
                let channel = Channel.from(item, channelNumber: channelNumber)
                channels.append(channel)
                channelNumber += 1
                
            case .movie:
                let movie = Movie.from(item)
                movies.append(movie)
                
            case .series:
                // Try to group episodes into shows
                let (showTitle, seasonNum, episodeNum) = parseSeriesInfo(from: item.name)
                
                if var existingShow = showsDict[showTitle] {
                    // Add episode to existing show
                    let episode = Episode.from(item, episodeNumber: episodeNum)
                    
                    if let seasonIndex = existingShow.seasons.firstIndex(where: { $0.seasonNumber == seasonNum }) {
                        existingShow.seasons[seasonIndex].episodes.append(episode)
                    } else {
                        var newSeason = Season(seasonNumber: seasonNum)
                        newSeason.episodes.append(episode)
                        existingShow.seasons.append(newSeason)
                    }
                    showsDict[showTitle] = existingShow
                } else {
                    // Create new show
                    let episode = Episode.from(item, episodeNumber: episodeNum)
                    var season = Season(seasonNumber: seasonNum)
                    season.episodes.append(episode)
                    
                    let show = Show(
                        title: showTitle,
                        posterURL: item.logoURL,
                        category: item.groupTitle,
                        seasons: [season]
                    )
                    showsDict[showTitle] = show
                }
            }
        }
        
        // Sort episodes within seasons
        let shows = showsDict.values.map { show -> Show in
            var sortedShow = show
            sortedShow.seasons = show.seasons.map { season -> Season in
                var sortedSeason = season
                sortedSeason.episodes = season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
                return sortedSeason
            }.sorted { $0.seasonNumber < $1.seasonNumber }
            return sortedShow
        }
        
        return ParsedContent(
            channels: channels,
            movies: movies,
            shows: Array(shows),
            categories: categories
        )
    }
    
    /// Parses series info from a title (e.g., "Breaking Bad S01E05" -> ("Breaking Bad", 1, 5))
    private func parseSeriesInfo(from title: String) -> (showTitle: String, season: Int, episode: Int) {
        // Try to match patterns like "S01E05", "s1e5", "Season 1 Episode 5"
        let patterns = [
            #"(.+?)\s*[Ss](\d+)[Ee](\d+)"#,
            #"(.+?)\s*Season\s*(\d+)\s*Episode\s*(\d+)"#,
            #"(.+?)\s*(\d+)[xX](\d+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                
                if let showRange = Range(match.range(at: 1), in: title),
                   let seasonRange = Range(match.range(at: 2), in: title),
                   let episodeRange = Range(match.range(at: 3), in: title) {
                    
                    let showTitle = String(title[showRange]).trimmingCharacters(in: .whitespaces)
                    let season = Int(title[seasonRange]) ?? 1
                    let episode = Int(title[episodeRange]) ?? 1
                    
                    return (showTitle, season, episode)
                }
            }
        }
        
        // Fallback: use full title as show name
        return (title, 1, 1)
    }
}
