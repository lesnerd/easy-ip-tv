import XCTest
@testable import EasyIpTv

@MainActor
final class PremiumManagerTests: XCTestCase {

    var manager: PremiumManager!

    override func setUp() async throws {
        manager = PremiumManager()
        // Ensure known state for each test
        manager.isPremium = false
        manager.subscriptionType = .free
    }

    // MARK: - Free user limits

    func testFreeUser_canAddPlaylist() {
        manager.isPremium = false
        XCTAssertTrue(manager.canAddPlaylist(currentCount: 0))
        XCTAssertFalse(manager.canAddPlaylist(currentCount: 1))
    }

    func testFreeUser_canAddFavorite() {
        manager.isPremium = false
        XCTAssertTrue(manager.canAddFavorite(currentCount: 9))
        XCTAssertFalse(manager.canAddFavorite(currentCount: 10))
    }

    func testFreeUser_canSelectQuality() {
        manager.isPremium = false
        XCTAssertFalse(manager.canSelectQuality)
    }

    func testFreeUser_canUseSubtitles() {
        manager.isPremium = false
        XCTAssertFalse(manager.canUseSubtitles)
    }

    func testFreeUser_canUseRecentlyWatched() {
        manager.isPremium = false
        XCTAssertFalse(manager.canUseRecentlyWatched)
    }

    func testFreeUser_continueWatchingLimit() {
        manager.isPremium = false
        XCTAssertEqual(manager.continueWatchingLimit, 3)
    }

    func testFreeUser_maxDownloads() {
        manager.isPremium = false
        XCTAssertEqual(manager.maxDownloads, 2)
    }

    func testFreeUser_canDownload() {
        manager.isPremium = false
        XCTAssertTrue(manager.canDownload(currentCount: 1))
        XCTAssertFalse(manager.canDownload(currentCount: 2))
    }

    func testFreeUser_shouldShowInterstitial() {
        manager.isPremium = false
        XCTAssertTrue(manager.shouldShowInterstitial(playCount: 5))
        XCTAssertFalse(manager.shouldShowInterstitial(playCount: 3))
    }

    func testFreeUser_canChangeRetention() {
        manager.isPremium = false
        XCTAssertFalse(manager.canChangeRetention)
    }

    // MARK: - Premium user (all limits removed)

    func testPremiumUser_canAddPlaylist() {
        manager.isPremium = true
        XCTAssertTrue(manager.canAddPlaylist(currentCount: 100))
    }

    func testPremiumUser_canAddFavorite() {
        manager.isPremium = true
        XCTAssertTrue(manager.canAddFavorite(currentCount: 1000))
    }

    func testPremiumUser_canSelectQuality() {
        manager.isPremium = true
        XCTAssertTrue(manager.canSelectQuality)
    }

    func testPremiumUser_canUseSubtitles() {
        manager.isPremium = true
        XCTAssertTrue(manager.canUseSubtitles)
    }

    func testPremiumUser_continueWatchingLimit() {
        manager.isPremium = true
        XCTAssertEqual(manager.continueWatchingLimit, 50)
    }

    func testPremiumUser_maxDownloads() {
        manager.isPremium = true
        XCTAssertEqual(manager.maxDownloads, Int.max)
    }

    func testPremiumUser_shouldShowInterstitial() {
        manager.isPremium = true
        XCTAssertFalse(manager.shouldShowInterstitial(playCount: 5))
        XCTAssertFalse(manager.shouldShowInterstitial(playCount: 10))
    }

    func testPremiumUser_canChangeRetention() {
        manager.isPremium = true
        XCTAssertTrue(manager.canChangeRetention)
    }
}
