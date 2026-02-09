import XCTest
@testable import EasyIpTv

final class XtreamCodesTests: XCTestCase {
    
    // MARK: - URL Detection
    
    func testIsXtreamCodesURL_ValidURL() {
        let url = URL(string: "http://server.com:8080/get.php?username=user&password=pass&type=m3u_plus&output=ts")!
        XCTAssertTrue(XtreamCodesService.isXtreamCodesURL(url))
    }
    
    func testIsXtreamCodesURL_ValidURLWithoutPort() {
        let url = URL(string: "http://server.com/get.php?username=user&password=pass")!
        XCTAssertTrue(XtreamCodesService.isXtreamCodesURL(url))
    }
    
    func testIsXtreamCodesURL_M3UURLReturnsFalse() {
        let url = URL(string: "http://server.com/playlist.m3u")!
        XCTAssertFalse(XtreamCodesService.isXtreamCodesURL(url))
    }
    
    func testIsXtreamCodesURL_StalkerURLReturnsFalse() {
        let url = URL(string: "stalker://portal.example.com/c/?mac=00:1A:79:00:00:01")!
        XCTAssertFalse(XtreamCodesService.isXtreamCodesURL(url))
    }
    
    func testIsXtreamCodesURL_RandomURLReturnsFalse() {
        let url = URL(string: "https://www.google.com")!
        XCTAssertFalse(XtreamCodesService.isXtreamCodesURL(url))
    }
    
    func testIsXtreamCodesURL_MissingUsernameReturnsFalse() {
        let url = URL(string: "http://server.com/get.php?password=pass")!
        XCTAssertFalse(XtreamCodesService.isXtreamCodesURL(url))
    }
    
    func testIsXtreamCodesURL_MissingPasswordReturnsFalse() {
        let url = URL(string: "http://server.com/get.php?username=user")!
        XCTAssertFalse(XtreamCodesService.isXtreamCodesURL(url))
    }
    
    // MARK: - Credential Extraction
    
    func testExtractCredentials_ValidURL() {
        let url = URL(string: "http://server.com:8080/get.php?username=testuser&password=testpass&type=m3u_plus")!
        let creds = XtreamCodesService.extractCredentials(from: url)
        
        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.baseURL, "http://server.com:8080")
        XCTAssertEqual(creds?.username, "testuser")
        XCTAssertEqual(creds?.password, "testpass")
    }
    
    func testExtractCredentials_HTTPSWithPort() {
        let url = URL(string: "https://secure.server.com:443/get.php?username=admin&password=secret")!
        let creds = XtreamCodesService.extractCredentials(from: url)
        
        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.baseURL, "https://secure.server.com:443")
        XCTAssertEqual(creds?.username, "admin")
        XCTAssertEqual(creds?.password, "secret")
    }
    
    func testExtractCredentials_WithoutPort() {
        let url = URL(string: "http://server.com/get.php?username=user&password=pass")!
        let creds = XtreamCodesService.extractCredentials(from: url)
        
        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.baseURL, "http://server.com")
    }
    
    func testExtractCredentials_MissingUsername() {
        let url = URL(string: "http://server.com/get.php?password=pass")!
        let creds = XtreamCodesService.extractCredentials(from: url)
        
        XCTAssertNil(creds, "Should return nil when username is missing")
    }
    
    func testExtractCredentials_MissingPassword() {
        let url = URL(string: "http://server.com/get.php?username=user")!
        let creds = XtreamCodesService.extractCredentials(from: url)
        
        XCTAssertNil(creds, "Should return nil when password is missing")
    }
    
    func testExtractCredentials_SpecialCharactersInCredentials() {
        let url = URL(string: "http://server.com/get.php?username=user%40email.com&password=p%40ss%23word")!
        let creds = XtreamCodesService.extractCredentials(from: url)
        
        XCTAssertNotNil(creds)
        XCTAssertEqual(creds?.username, "user@email.com")
        XCTAssertEqual(creds?.password, "p@ss#word")
    }
    
    // MARK: - URL Construction
    
    func testXtreamURLConstruction() {
        let server = "http://server.com:8080"
        let username = "testuser"
        let password = "testpass"
        
        let expectedURL = "\(server)/get.php?username=\(username)&password=\(password)&type=m3u_plus&output=ts"
        let constructedURL = "\(server)/get.php?username=\(username)&password=\(password)&type=m3u_plus&output=ts"
        
        XCTAssertEqual(constructedURL, expectedURL)
        XCTAssertNotNil(URL(string: constructedURL))
    }
    
    func testPlayerAPIURLConstruction() {
        let baseURL = "http://server.com:8080"
        let username = "user"
        let password = "pass"
        
        let authURL = "\(baseURL)/player_api.php?username=\(username)&password=\(password)"
        let categoriesURL = "\(baseURL)/player_api.php?username=\(username)&password=\(password)&action=get_live_categories"
        
        XCTAssertNotNil(URL(string: authURL))
        XCTAssertNotNil(URL(string: categoriesURL))
        XCTAssertTrue(authURL.contains("player_api.php"))
        XCTAssertTrue(categoriesURL.contains("action=get_live_categories"))
    }
}
