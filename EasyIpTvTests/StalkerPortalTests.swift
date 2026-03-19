import XCTest
@testable import EasyIpTv

final class StalkerPortalTests: XCTestCase {
    
    // MARK: - URL Detection
    
    func testIsStalkerPortalURL_ValidStalkerScheme() {
        let url = URL(string: "stalker://portal.example.com/c/?mac=00:1A:79:00:00:01")!
        XCTAssertTrue(StalkerPortalService.isStalkerPortalURL(url))
    }
    
    func testIsStalkerPortalURL_HTTPURLReturnsFalse() {
        let url = URL(string: "http://portal.example.com/c/")!
        XCTAssertFalse(StalkerPortalService.isStalkerPortalURL(url))
    }
    
    func testIsStalkerPortalURL_XtreamURLReturnsFalse() {
        let url = URL(string: "http://server.com/get.php?username=user&password=pass")!
        XCTAssertFalse(StalkerPortalService.isStalkerPortalURL(url))
    }
    
    func testIsStalkerPortalURL_M3UURLReturnsFalse() {
        let url = URL(string: "http://server.com/playlist.m3u")!
        XCTAssertFalse(StalkerPortalService.isStalkerPortalURL(url))
    }
    
    // MARK: - MAC Address Validation
    
    func testIsValidMACAddress_ValidFormats() {
        XCTAssertTrue(StalkerPortalService.isValidMACAddress("00:1A:79:AB:CD:EF"))
        XCTAssertTrue(StalkerPortalService.isValidMACAddress("aa:bb:cc:dd:ee:ff"))
        XCTAssertTrue(StalkerPortalService.isValidMACAddress("00:00:00:00:00:00"))
        XCTAssertTrue(StalkerPortalService.isValidMACAddress("FF:FF:FF:FF:FF:FF"))
        XCTAssertTrue(StalkerPortalService.isValidMACAddress("12:34:56:78:9A:BC"))
    }
    
    func testIsValidMACAddress_InvalidFormats() {
        XCTAssertFalse(StalkerPortalService.isValidMACAddress(""))
        XCTAssertFalse(StalkerPortalService.isValidMACAddress("not-a-mac"))
        XCTAssertFalse(StalkerPortalService.isValidMACAddress("00:1A:79:AB:CD")) // Too short
        XCTAssertFalse(StalkerPortalService.isValidMACAddress("00:1A:79:AB:CD:EF:00")) // Too long
        XCTAssertFalse(StalkerPortalService.isValidMACAddress("001A79ABCDEF")) // No colons
        XCTAssertFalse(StalkerPortalService.isValidMACAddress("00-1A-79-AB-CD-EF")) // Dashes instead of colons
        XCTAssertFalse(StalkerPortalService.isValidMACAddress("GG:HH:II:JJ:KK:LL")) // Invalid hex
        XCTAssertFalse(StalkerPortalService.isValidMACAddress("00:1A:79:AB:CD:E")) // Incomplete last octet
    }
    
    // MARK: - Credential Extraction
    
    func testExtractCredentials_ValidStalkerURL() {
        let url = URL(string: "stalker://portal.example.com/c/?mac=00:1A:79:AB:CD:EF")!
        let creds = StalkerPortalService.extractCredentials(from: url)
        
        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.portalURL, "http://portal.example.com/c/")
        XCTAssertEqual(creds?.macAddress, "00:1A:79:AB:CD:EF")
    }
    
    func testExtractCredentials_StalkerURLWithPort() {
        let url = URL(string: "stalker://portal.example.com:8080/c/?mac=AA:BB:CC:DD:EE:FF")!
        let creds = StalkerPortalService.extractCredentials(from: url)
        
        XCTAssertNotNil(creds)
        XCTAssertTrue(creds?.portalURL.contains("8080") ?? false)
        XCTAssertEqual(creds?.macAddress, "AA:BB:CC:DD:EE:FF")
    }
    
    func testExtractCredentials_NonStalkerScheme() {
        let url = URL(string: "http://portal.example.com/c/?mac=00:1A:79:AB:CD:EF")!
        let creds = StalkerPortalService.extractCredentials(from: url)
        
        XCTAssertNil(creds, "Should return nil for non-stalker scheme")
    }
    
    func testExtractCredentials_MissingMAC() {
        let url = URL(string: "stalker://portal.example.com/c/")!
        let creds = StalkerPortalService.extractCredentials(from: url)
        
        XCTAssertNil(creds, "Should return nil when MAC is missing")
    }
    
    // MARK: - Build Stalker URL
    
    func testBuildStalkerURL() {
        let url = StalkerPortalService.buildStalkerURL(
            portalURL: "http://portal.example.com/c",
            macAddress: "00:1A:79:AB:CD:EF"
        )
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "stalker")
        XCTAssertTrue(url?.absoluteString.contains("mac=") ?? false)
    }
    
    func testBuildStalkerURL_RoundTrip() {
        let originalPortal = "http://portal.example.com/c"
        let originalMAC = "00:1A:79:AB:CD:EF"
        
        guard let url = StalkerPortalService.buildStalkerURL(portalURL: originalPortal, macAddress: originalMAC) else {
            XCTFail("Failed to build URL")
            return
        }
        
        let extracted = StalkerPortalService.extractCredentials(from: url)
        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.macAddress, originalMAC)
    }
    
    // MARK: - Stream URL Extraction
    
    func testExtractStreamURL_FFmpegPrefix() {
        let cmd = "ffmpeg http://stream.example.com/live/channel123.ts"
        let url = StalkerPortalService.extractStreamURL(from: cmd)
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "http://stream.example.com/live/channel123.ts")
    }
    
    func testExtractStreamURL_FFrtPrefix() {
        let cmd = "ffrt http://stream.example.com/live/channel456.ts"
        let url = StalkerPortalService.extractStreamURL(from: cmd)
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "http://stream.example.com/live/channel456.ts")
    }
    
    func testExtractStreamURL_DirectURL() {
        let cmd = "http://stream.example.com/live/channel789.ts"
        let url = StalkerPortalService.extractStreamURL(from: cmd)
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "http://stream.example.com/live/channel789.ts")
    }
    
    func testExtractStreamURL_WithWhitespace() {
        let cmd = "  ffmpeg http://stream.example.com/live/test.ts  "
        let url = StalkerPortalService.extractStreamURL(from: cmd)
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "http://stream.example.com/live/test.ts")
    }
    
    func testExtractStreamURL_EmptyString() {
        let url = StalkerPortalService.extractStreamURL(from: "")
        XCTAssertNil(url)
    }
    
    func testExtractStreamURL_InvalidURL() {
        let url = StalkerPortalService.extractStreamURL(from: "")
        XCTAssertNil(url)
    }
}
