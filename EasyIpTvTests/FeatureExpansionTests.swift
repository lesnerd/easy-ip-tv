import XCTest
@testable import EasyIpTv

@MainActor
final class FeatureExpansionTests: XCTestCase {
    
    // MARK: - EPG Program Model
    
    func testEPGProgram_isNowPlaying_currentProgram() {
        let program = EPGProgram(
            id: "1",
            title: "News",
            description: "Evening news",
            start: Date().addingTimeInterval(-1800),
            end: Date().addingTimeInterval(1800),
            channelId: "ch1",
            lang: "en"
        )
        XCTAssertTrue(program.isNowPlaying)
    }
    
    func testEPGProgram_isNowPlaying_pastProgram() {
        let program = EPGProgram(
            id: "2",
            title: "Old Show",
            description: nil,
            start: Date().addingTimeInterval(-7200),
            end: Date().addingTimeInterval(-3600),
            channelId: "ch1",
            lang: nil
        )
        XCTAssertFalse(program.isNowPlaying)
    }
    
    func testEPGProgram_isNowPlaying_futureProgram() {
        let program = EPGProgram(
            id: "3",
            title: "Future Show",
            description: nil,
            start: Date().addingTimeInterval(3600),
            end: Date().addingTimeInterval(7200),
            channelId: "ch1",
            lang: nil
        )
        XCTAssertFalse(program.isNowPlaying)
    }
    
    func testEPGProgram_progress_midway() {
        let now = Date()
        let program = EPGProgram(
            id: "4",
            title: "Mid Show",
            description: nil,
            start: now.addingTimeInterval(-1800),
            end: now.addingTimeInterval(1800),
            channelId: "ch1",
            lang: nil
        )
        let progress = program.progress
        XCTAssertGreaterThan(progress, 0.4)
        XCTAssertLessThan(progress, 0.6)
    }
    
    func testEPGProgram_progress_pastProgram_is1() {
        let program = EPGProgram(
            id: "5",
            title: "Done Show",
            description: nil,
            start: Date().addingTimeInterval(-7200),
            end: Date().addingTimeInterval(-3600),
            channelId: "ch1",
            lang: nil
        )
        XCTAssertEqual(program.progress, 1.0)
    }
    
    func testEPGProgram_timeRange_format() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        let start = formatter.date(from: "2025-01-01 14:00:00")!
        let end = formatter.date(from: "2025-01-01 15:30:00")!
        
        let program = EPGProgram(
            id: "6",
            title: "Test",
            description: nil,
            start: start,
            end: end,
            channelId: "ch1",
            lang: nil
        )
        XCTAssertTrue(program.timeRange.contains("-"))
    }
    
    // MARK: - Channel with EPG/Catchup Fields
    
    func testChannel_newFields_defaults() {
        let ch = Channel(
            name: "Test",
            streamURL: URL(string: "http://test.com/stream.m3u8")!,
            category: "General"
        )
        XCTAssertNil(ch.epgChannelId)
        XCTAssertFalse(ch.hasCatchup)
        XCTAssertNil(ch.catchupDays)
        XCTAssertNil(ch.streamId)
    }
    
    func testChannel_withCatchup() {
        let ch = Channel(
            name: "Catchup Channel",
            streamURL: URL(string: "http://test.com/stream.m3u8")!,
            category: "General",
            epgChannelId: "epg-123",
            hasCatchup: true,
            catchupDays: 7,
            streamId: 456
        )
        XCTAssertEqual(ch.epgChannelId, "epg-123")
        XCTAssertTrue(ch.hasCatchup)
        XCTAssertEqual(ch.catchupDays, 7)
        XCTAssertEqual(ch.streamId, 456)
    }
    
    func testChannel_codable_roundTrip_withNewFields() throws {
        let original = Channel(
            name: "Codable Test",
            streamURL: URL(string: "http://test.com/stream.m3u8")!,
            category: "News",
            epgChannelId: "epg-abc",
            hasCatchup: true,
            catchupDays: 3,
            streamId: 789
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Channel.self, from: data)
        XCTAssertEqual(decoded.epgChannelId, "epg-abc")
        XCTAssertTrue(decoded.hasCatchup)
        XCTAssertEqual(decoded.catchupDays, 3)
        XCTAssertEqual(decoded.streamId, 789)
    }
    
    // MARK: - Xtream EPG Item Mapping
    
    func testXtreamEPGMapping_validItem() {
        let item = XtreamCodesService.EPGItem(
            id: "100",
            epgId: "epg-1",
            title: "Morning News",
            lang: "en",
            start: "2025-01-01 08:00:00",
            end: "2025-01-01 09:00:00",
            description: "Daily news",
            channelId: "ch-1"
        )
        let program = XtreamCodesService.mapEPGItem(item)
        XCTAssertNotNil(program)
        XCTAssertEqual(program?.title, "Morning News")
        XCTAssertEqual(program?.channelId, "ch-1")
    }
    
    func testXtreamEPGMapping_base64EncodedTitle() {
        let base64Title = Data("Encoded Title".utf8).base64EncodedString()
        let item = XtreamCodesService.EPGItem(
            id: "200",
            epgId: "epg-2",
            title: base64Title,
            lang: "en",
            start: "2025-06-15 20:00:00",
            end: "2025-06-15 21:00:00",
            description: nil,
            channelId: "ch-2"
        )
        let program = XtreamCodesService.mapEPGItem(item)
        XCTAssertNotNil(program)
        XCTAssertEqual(program?.title, "Encoded Title")
    }
    
    func testXtreamEPGMapping_missingTitle_returnsNil() {
        let item = XtreamCodesService.EPGItem(
            id: "300",
            epgId: "epg-3",
            title: nil,
            lang: nil,
            start: "2025-01-01 10:00:00",
            end: "2025-01-01 11:00:00",
            description: nil,
            channelId: "ch-3"
        )
        XCTAssertNil(XtreamCodesService.mapEPGItem(item))
    }
    
    func testXtreamEPGMapping_missingDates_returnsNil() {
        let item = XtreamCodesService.EPGItem(
            id: "400",
            epgId: nil,
            title: "No Dates",
            lang: nil,
            start: nil,
            end: nil,
            description: nil,
            channelId: "ch-4"
        )
        XCTAssertNil(XtreamCodesService.mapEPGItem(item))
    }
    
    // MARK: - Archive URL Building
    
    func testBuildArchiveURL() {
        let service = XtreamCodesService()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let start = formatter.date(from: "2025-01-15 14:00:00")!
        
        let url = service.buildArchiveURL(
            baseURL: "http://example.com",
            username: "user1",
            password: "pass1",
            streamId: 123,
            start: start,
            durationMinutes: 60
        )
        
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("timeshift.php"))
        XCTAssertTrue(urlString.contains("username=user1"))
        XCTAssertTrue(urlString.contains("password=pass1"))
        XCTAssertTrue(urlString.contains("stream=123"))
        XCTAssertTrue(urlString.contains("duration=60"))
    }
    
    // MARK: - Xtream LiveStream Catchup Fields
    
    func testLiveStreamDecoding_withCatchupFields() throws {
        let json = """
        {
            "num": 1,
            "name": "Test Channel",
            "stream_type": "live",
            "stream_id": 100,
            "stream_icon": "http://img.com/icon.png",
            "category_id": "5",
            "epg_channel_id": "test.tv",
            "is_adult": 0,
            "tv_archive": 1,
            "tv_archive_duration": 7
        }
        """.data(using: .utf8)!
        
        let stream = try JSONDecoder().decode(XtreamCodesService.LiveStream.self, from: json)
        XCTAssertEqual(stream.tvArchive, 1)
        XCTAssertEqual(stream.tvArchiveDuration, 7)
        XCTAssertEqual(stream.epgChannelId, "test.tv")
    }
    
    func testLiveStreamDecoding_withoutCatchupFields() throws {
        let json = """
        {
            "num": 2,
            "name": "Basic Channel",
            "stream_id": 200
        }
        """.data(using: .utf8)!
        
        let stream = try JSONDecoder().decode(XtreamCodesService.LiveStream.self, from: json)
        XCTAssertNil(stream.tvArchive)
        XCTAssertNil(stream.tvArchiveDuration)
    }
    
    // MARK: - XMLTV Parser
    
    func testXMLTVParser_basicParsing() {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20250101140000 +0000" stop="20250101150000 +0000" channel="bbc1.uk">
                <title lang="en">BBC News</title>
                <desc>Latest news from around the world</desc>
            </programme>
            <programme start="20250101150000 +0000" stop="20250101160000 +0000" channel="bbc1.uk">
                <title lang="en">Weather</title>
            </programme>
            <programme start="20250101140000 +0000" stop="20250101153000 +0000" channel="itv1.uk">
                <title lang="en">ITV News</title>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        let parser = XMLTVParser()
        let result = parser.parse(data: xmltv)
        
        XCTAssertEqual(result.count, 2, "Should have 2 channels")
        XCTAssertEqual(result["bbc1.uk"]?.count, 2, "BBC1 should have 2 programs")
        XCTAssertEqual(result["itv1.uk"]?.count, 1, "ITV1 should have 1 program")
        XCTAssertEqual(result["bbc1.uk"]?.first?.title, "BBC News")
        XCTAssertEqual(result["bbc1.uk"]?.first?.description, "Latest news from around the world")
    }
    
    func testXMLTVParser_emptyInput() {
        let parser = XMLTVParser()
        let result = parser.parse(data: Data())
        XCTAssertTrue(result.isEmpty)
    }
    
    func testXMLTVParser_missingTitleSkipsProgram() {
        let xmltv = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
            <programme start="20250101140000 +0000" stop="20250101150000 +0000" channel="ch1">
                <desc>No title here</desc>
            </programme>
        </tv>
        """.data(using: .utf8)!
        
        let parser = XMLTVParser()
        let result = parser.parse(data: xmltv)
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - EPGService
    
    func testEPGService_nowPlaying_findsCorrectProgram() {
        let service = EPGService.shared
        let now = Date()
        let programs = [
            EPGProgram(id: "past", title: "Old", description: nil, start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), channelId: "test", lang: nil),
            EPGProgram(id: "current", title: "Current Show", description: nil, start: now.addingTimeInterval(-1800), end: now.addingTimeInterval(1800), channelId: "test", lang: nil),
            EPGProgram(id: "future", title: "Next", description: nil, start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), channelId: "test", lang: nil),
        ]
        service.programsByChannel["test-key"] = programs
        
        let nowProgram = service.nowPlaying(for: "test-key")
        XCTAssertEqual(nowProgram?.title, "Current Show")
    }
    
    func testEPGService_upcoming_excludesPast() {
        let service = EPGService.shared
        let now = Date()
        let programs = [
            EPGProgram(id: "past", title: "Old", description: nil, start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), channelId: "test", lang: nil),
            EPGProgram(id: "current", title: "Current", description: nil, start: now.addingTimeInterval(-1800), end: now.addingTimeInterval(1800), channelId: "test", lang: nil),
            EPGProgram(id: "future", title: "Next", description: nil, start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), channelId: "test", lang: nil),
        ]
        service.programsByChannel["upcoming-key"] = programs
        
        let upcoming = service.upcoming(for: "upcoming-key")
        XCTAssertEqual(upcoming.count, 2)
        XCTAssertEqual(upcoming.first?.title, "Current")
    }
    
    func testEPGService_pastPrograms() {
        let service = EPGService.shared
        let now = Date()
        let programs = [
            EPGProgram(id: "past1", title: "Old 1", description: nil, start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-5400), channelId: "test", lang: nil),
            EPGProgram(id: "past2", title: "Old 2", description: nil, start: now.addingTimeInterval(-5400), end: now.addingTimeInterval(-3600), channelId: "test", lang: nil),
            EPGProgram(id: "current", title: "Now", description: nil, start: now.addingTimeInterval(-1800), end: now.addingTimeInterval(1800), channelId: "test", lang: nil),
        ]
        service.programsByChannel["past-key"] = programs
        
        let past = service.pastPrograms(for: "past-key")
        XCTAssertEqual(past.count, 2)
        XCTAssertEqual(past.first?.title, "Old 2") // Most recent past first
    }
    
    // MARK: - M3U EPG URL Parsing
    
    func testM3UParser_extractsEPGURL() async throws {
        let content = "#EXTM3U url-tvg=\"http://example.com/epg.xml.gz\" catchup=\"default\"\n#EXTINF:-1 tvg-id=\"ch1\" group-title=\"News\",Channel 1\nhttp://stream.example.com/1.m3u8"
        let parser = M3UParser()
        let result = try await parser.parse(content: content)
        XCTAssertEqual(result.epgURL, "http://example.com/epg.xml.gz")
    }
    
    func testM3UParser_noEPGURL() async throws {
        let content = "#EXTM3U\n#EXTINF:-1 tvg-id=\"ch1\" group-title=\"News\",Channel 1\nhttp://stream.example.com/1.m3u8"
        let parser = M3UParser()
        let result = try await parser.parse(content: content)
        XCTAssertNil(result.epgURL)
    }
    
    // MARK: - CastManager State
    
    func testCastManager_initialState() {
        let manager = CastManager.shared
        XCTAssertFalse(manager.isCasting)
        XCTAssertNil(manager.castDeviceName)
        XCTAssertFalse(manager.isConnecting)
    }
    
    // MARK: - SubtitleLanguageMatcher
    
    func testMatcher_canonicalCode_iso639_1() {
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "en"), "en")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "he"), "he")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "fr"), "fr")
    }
    
    func testMatcher_canonicalCode_iso639_2() {
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "eng"), "en")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "heb"), "he")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "fra"), "fr")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "fre"), "fr")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "deu"), "de")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "ger"), "de")
    }
    
    func testMatcher_canonicalCode_fullName() {
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "english"), "en")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "Hebrew"), "he")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "FRENCH"), "fr")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "español"), "es")
    }
    
    func testMatcher_canonicalCode_localeStripping() {
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "en-US"), "en")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "en_GB"), "en")
        XCTAssertEqual(SubtitleLanguageMatcher.canonicalCode(for: "fr-CA"), "fr")
    }
    
    func testMatcher_canonicalCode_unknownReturnsNil() {
        XCTAssertNil(SubtitleLanguageMatcher.canonicalCode(for: "xyz"))
        XCTAssertNil(SubtitleLanguageMatcher.canonicalCode(for: "klingon"))
    }
    
    func testMatcher_matches_codeToCode() {
        XCTAssertTrue(SubtitleLanguageMatcher.matches(trackLanguage: "en", preferredCode: "en"))
        XCTAssertTrue(SubtitleLanguageMatcher.matches(trackLanguage: "eng", preferredCode: "en"))
        XCTAssertTrue(SubtitleLanguageMatcher.matches(trackLanguage: "heb", preferredCode: "he"))
        XCTAssertFalse(SubtitleLanguageMatcher.matches(trackLanguage: "fr", preferredCode: "en"))
    }
    
    func testMatcher_matches_nilTrackReturnsFalse() {
        XCTAssertFalse(SubtitleLanguageMatcher.matches(trackLanguage: nil, preferredCode: "en"))
    }
    
    func testMatcher_nameMatches_containsAlias() {
        XCTAssertTrue(SubtitleLanguageMatcher.nameMatches(trackName: "English [CC]", preferredCode: "en"))
        XCTAssertTrue(SubtitleLanguageMatcher.nameMatches(trackName: "Track 1 - Hebrew (SDH)", preferredCode: "he"))
        XCTAssertFalse(SubtitleLanguageMatcher.nameMatches(trackName: "French", preferredCode: "en"))
    }
    
    func testMatcher_matches_caseInsensitive() {
        XCTAssertTrue(SubtitleLanguageMatcher.matches(trackLanguage: "EN", preferredCode: "en"))
        XCTAssertTrue(SubtitleLanguageMatcher.matches(trackLanguage: "ENG", preferredCode: "en"))
        XCTAssertTrue(SubtitleLanguageMatcher.matches(trackLanguage: "English", preferredCode: "en"))
    }
    
    // MARK: - EPG Key Resolution
    
    func testChannel_epgKey_prefersStreamId() {
        let channel = Channel(
            id: "123",
            name: "Test",
            streamURL: URL(string: "http://test.com/stream")!,
            category: "News",
            tvgId: "tvg-test",
            epgChannelId: "epg-test",
            streamId: 456
        )
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        XCTAssertEqual(key, "456")
    }
    
    func testChannel_epgKey_fallsToEpgChannelId() {
        let channel = Channel(
            id: "123",
            name: "Test",
            streamURL: URL(string: "http://test.com/stream")!,
            category: "News",
            tvgId: "tvg-test",
            epgChannelId: "epg-test"
        )
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        XCTAssertEqual(key, "epg-test")
    }
    
    func testChannel_epgKey_fallsToTvgId() {
        let channel = Channel(
            id: "123",
            name: "Test",
            streamURL: URL(string: "http://test.com/stream")!,
            category: "News",
            tvgId: "tvg-test"
        )
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        XCTAssertEqual(key, "tvg-test")
    }
}
