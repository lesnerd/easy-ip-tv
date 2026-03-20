import Foundation

@MainActor
class EPGService: ObservableObject {
    static let shared = EPGService()
    
    @Published var programsByChannel: [String: [EPGProgram]] = [:]
    
    private var lastFetchTime: [String: Date] = [:]
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    private let xtreamService = XtreamCodesService()
    
    func nowPlaying(for channelId: String) -> EPGProgram? {
        programsByChannel[channelId]?.first(where: { $0.isNowPlaying })
    }
    
    func upcoming(for channelId: String) -> [EPGProgram] {
        let now = Date()
        return (programsByChannel[channelId] ?? [])
            .filter { $0.end > now }
            .sorted { $0.start < $1.start }
    }
    
    func pastPrograms(for channelId: String) -> [EPGProgram] {
        let now = Date()
        return (programsByChannel[channelId] ?? [])
            .filter { $0.end <= now }
            .sorted { $0.start > $1.start }
    }
    
    func fetchEPG(for channel: Channel, baseURL: String, username: String, password: String) async {
        guard let streamId = channel.streamId else { return }
        let key = "\(streamId)"
        
        if let lastFetch = lastFetchTime[key],
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            return
        }
        
        do {
            let programs = try await xtreamService.getShortEPG(
                baseURL: baseURL,
                username: username,
                password: password,
                streamId: streamId
            )
            programsByChannel[key] = programs
            lastFetchTime[key] = Date()
        } catch {
            NSLog("[EPG] Failed to fetch EPG for stream %d: %@", streamId, error.localizedDescription)
        }
    }
    
    func fetchFullEPG(for channel: Channel, baseURL: String, username: String, password: String) async {
        guard let streamId = channel.streamId else { return }
        let key = "\(streamId)"
        
        do {
            let programs = try await xtreamService.getFullEPG(
                baseURL: baseURL,
                username: username,
                password: password,
                streamId: streamId
            )
            programsByChannel[key] = programs
            lastFetchTime[key] = Date()
        } catch {
            NSLog("[EPG] Failed to fetch full EPG for stream %d: %@", streamId, error.localizedDescription)
        }
    }
    
    func fetchBatchEPG(for channels: [Channel], baseURL: String, username: String, password: String) async {
        let channelsToFetch = channels.filter { ch in
            guard let sid = ch.streamId else { return false }
            let key = "\(sid)"
            if let lastFetch = lastFetchTime[key],
               Date().timeIntervalSince(lastFetch) < cacheDuration {
                return false
            }
            return true
        }.prefix(20)
        
        await withTaskGroup(of: Void.self) { group in
            for channel in channelsToFetch {
                group.addTask { [weak self] in
                    await self?.fetchEPG(
                        for: channel,
                        baseURL: baseURL,
                        username: username,
                        password: password
                    )
                }
            }
        }
    }
    
    // MARK: - XMLTV Parsing
    
    func loadXMLTV(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = XMLTVParser()
            let programs = parser.parse(data: data)
            for (channelId, channelPrograms) in programs {
                if var existing = programsByChannel[channelId] {
                    existing.append(contentsOf: channelPrograms)
                    programsByChannel[channelId] = existing
                } else {
                    programsByChannel[channelId] = channelPrograms
                }
            }
            NSLog("[EPG] Loaded XMLTV with %d channels", programs.count)
        } catch {
            NSLog("[EPG] Failed to load XMLTV: %@", error.localizedDescription)
        }
    }
}

// MARK: - XMLTV Parser

class XMLTVParser: NSObject, XMLParserDelegate {
    private var programs: [String: [EPGProgram]] = [:]
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDesc = ""
    private var currentStart: Date?
    private var currentEnd: Date?
    private var currentChannelId = ""
    private var currentLang: String?
    
    private static let xmltvFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmmss Z"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    func parse(data: Data) -> [String: [EPGProgram]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return programs
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        if elementName == "programme" {
            currentTitle = ""
            currentDesc = ""
            currentLang = nil
            currentChannelId = attributeDict["channel"] ?? ""
            if let startStr = attributeDict["start"] {
                currentStart = Self.xmltvFormatter.date(from: startStr)
            }
            if let stopStr = attributeDict["stop"] {
                currentEnd = Self.xmltvFormatter.date(from: stopStr)
            }
        }
        
        if elementName == "title" {
            currentLang = attributeDict["lang"]
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title":
            currentTitle += string
        case "desc":
            currentDesc += string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "programme" {
            guard let start = currentStart, let end = currentEnd, !currentTitle.isEmpty else { return }
            
            let program = EPGProgram(
                id: "\(currentChannelId)_\(start.timeIntervalSince1970)",
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDesc.isEmpty ? nil : currentDesc.trimmingCharacters(in: .whitespacesAndNewlines),
                start: start,
                end: end,
                channelId: currentChannelId,
                lang: currentLang
            )
            
            if programs[currentChannelId] != nil {
                programs[currentChannelId]!.append(program)
            } else {
                programs[currentChannelId] = [program]
            }
        }
        currentElement = ""
    }
}
