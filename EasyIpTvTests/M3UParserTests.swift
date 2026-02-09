import XCTest
@testable import EasyIpTv

final class M3UParserTests: XCTestCase {
    
    var parser: M3UParser!
    
    override func setUp() async throws {
        parser = M3UParser()
    }
    
    // MARK: - Valid M3U Parsing
    
    func testParseValidM3UWithChannels() async throws {
        let m3uContent = """
        #EXTM3U
        #EXTINF:-1 tvg-id="ch1" tvg-name="Channel 1" tvg-logo="http://logo.com/1.png" group-title="Sports",Channel 1
        http://stream.example.com/channel1.m3u8
        #EXTINF:-1 tvg-id="ch2" tvg-name="Channel 2" tvg-logo="http://logo.com/2.png" group-title="News",Channel 2
        http://stream.example.com/channel2.m3u8
        """
        
        let url = try createTempM3U(content: m3uContent)
        let result = try await parser.parse(from: url)
        
        XCTAssertFalse(result.channels.isEmpty, "Should parse channels")
        XCTAssertEqual(result.channels.count, 2)
        XCTAssertEqual(result.channels[0].name, "Channel 1")
        XCTAssertEqual(result.channels[1].name, "Channel 2")
    }
    
    func testParseM3UWithCategories() async throws {
        let m3uContent = """
        #EXTM3U
        #EXTINF:-1 group-title="Sports",ESPN
        http://stream.example.com/espn.m3u8
        #EXTINF:-1 group-title="Sports",Fox Sports
        http://stream.example.com/fox.m3u8
        #EXTINF:-1 group-title="News",CNN
        http://stream.example.com/cnn.m3u8
        """
        
        let url = try createTempM3U(content: m3uContent)
        let result = try await parser.parse(from: url)
        
        XCTAssertGreaterThanOrEqual(result.channels.count, 3)
        
        let sportsChannels = result.channels.filter { $0.category == "Sports" }
        let newsChannels = result.channels.filter { $0.category == "News" }
        
        XCTAssertEqual(sportsChannels.count, 2, "Should have 2 Sports channels")
        XCTAssertEqual(newsChannels.count, 1, "Should have 1 News channel")
    }
    
    func testParseM3UWithLogos() async throws {
        let m3uContent = """
        #EXTM3U
        #EXTINF:-1 tvg-logo="http://logo.com/test.png" group-title="Test",Test Channel
        http://stream.example.com/test.m3u8
        """
        
        let url = try createTempM3U(content: m3uContent)
        let result = try await parser.parse(from: url)
        
        XCTAssertEqual(result.channels.count, 1)
        XCTAssertNotNil(result.channels.first?.logoURL)
        XCTAssertEqual(result.channels.first?.logoURL?.absoluteString, "http://logo.com/test.png")
    }
    
    // MARK: - Edge Cases
    
    func testParseEmptyM3U() async {
        let m3uContent = "#EXTM3U\n"
        
        do {
            let url = try createTempM3U(content: m3uContent)
            let result = try await parser.parse(from: url)
            // Empty playlist should either throw or return empty content
            XCTAssertTrue(result.channels.isEmpty && result.movies.isEmpty)
        } catch {
            // Expected for empty playlists
            XCTAssertTrue(true)
        }
    }
    
    func testParseInvalidFormat() async {
        let invalidContent = "This is not an M3U file\nJust some random text"
        
        do {
            let url = try createTempM3U(content: invalidContent)
            _ = try await parser.parse(from: url)
            XCTFail("Should throw for invalid format")
        } catch {
            // Expected
            XCTAssertTrue(true)
        }
    }
    
    func testParseM3UWithStreamURLs() async throws {
        let m3uContent = """
        #EXTM3U
        #EXTINF:-1 group-title="Live",Test
        http://stream.example.com/live/123/456/789.ts
        """
        
        let url = try createTempM3U(content: m3uContent)
        let result = try await parser.parse(from: url)
        
        XCTAssertFalse(result.channels.isEmpty)
        XCTAssertEqual(result.channels.first?.streamURL.absoluteString, "http://stream.example.com/live/123/456/789.ts")
    }
    
    // MARK: - Helpers
    
    private func createTempM3U(content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).m3u")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
