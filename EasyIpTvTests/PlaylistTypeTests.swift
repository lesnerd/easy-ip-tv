import XCTest
@testable import EasyIpTv

final class PlaylistTypeTests: XCTestCase {
    
    // MARK: - Playlist Type Detection
    
    func testDetectM3UURL() {
        let urls = [
            URL(string: "http://server.com/playlist.m3u")!,
            URL(string: "http://server.com/playlist.m3u8")!,
            URL(string: "https://example.com/iptv/channels.m3u")!,
            URL(string: "http://server.com/live/streams.m3u8")!,
            URL(string: "http://server.com/some/path")!, // Unknown = defaults to M3U
        ]
        
        for url in urls {
            let type = StorageService.playlistType(for: url)
            XCTAssertEqual(type, .m3u, "URL \(url) should be detected as M3U")
        }
    }
    
    func testDetectXtreamCodesURL() {
        let urls = [
            URL(string: "http://server.com:8080/get.php?username=user&password=pass&type=m3u_plus&output=ts")!,
            URL(string: "http://server.com/get.php?username=admin&password=secret")!,
            URL(string: "https://secure.server.com:443/get.php?username=test&password=test123")!,
        ]
        
        for url in urls {
            let type = StorageService.playlistType(for: url)
            XCTAssertEqual(type, .xtreamCodes, "URL \(url) should be detected as Xtream Codes")
        }
    }
    
    func testDetectStalkerPortalURL() {
        let urls = [
            URL(string: "stalker://portal.example.com/c/?mac=00:1A:79:AB:CD:EF")!,
            URL(string: "stalker://192.168.1.100:8080/c/?mac=AA:BB:CC:DD:EE:FF")!,
        ]
        
        for url in urls {
            let type = StorageService.playlistType(for: url)
            XCTAssertEqual(type, .stalkerPortal, "URL \(url) should be detected as Stalker Portal")
        }
    }
    
    // MARK: - Priority / Routing
    
    func testStalkerDetectedBeforeXtream() {
        // Stalker uses its own scheme, so there's no ambiguity,
        // but verify the detection order works correctly
        let stalkerURL = URL(string: "stalker://portal.com/c/?mac=00:1A:79:00:00:01")!
        let xtreamURL = URL(string: "http://server.com/get.php?username=u&password=p")!
        
        XCTAssertEqual(StorageService.playlistType(for: stalkerURL), .stalkerPortal)
        XCTAssertEqual(StorageService.playlistType(for: xtreamURL), .xtreamCodes)
    }
    
    func testXtreamDetectedBeforeM3U() {
        // An Xtream URL with get.php, username, and password should NOT fall through to M3U
        let url = URL(string: "http://server.com:8080/get.php?username=test&password=test")!
        XCTAssertEqual(StorageService.playlistType(for: url), .xtreamCodes)
        XCTAssertNotEqual(StorageService.playlistType(for: url), .m3u)
    }
    
    // MARK: - Edge Cases
    
    func testURLWithGetPHPButNoCredentials_IsM3U() {
        // Has get.php but missing credentials
        let url = URL(string: "http://server.com/get.php?type=m3u_plus")!
        XCTAssertEqual(StorageService.playlistType(for: url), .m3u)
    }
    
    func testHTTPSXtreamURL() {
        let url = URL(string: "https://secure.server.com/get.php?username=u&password=p")!
        XCTAssertEqual(StorageService.playlistType(for: url), .xtreamCodes)
    }
}

