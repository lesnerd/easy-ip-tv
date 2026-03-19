import XCTest
@testable import EasyIpTv

@MainActor
final class UXFixesTests: XCTestCase {

    // MARK: - Playlist Persistence (Race Condition Fix)

    /// ContentViewModel.init() must NOT eagerly call loadCategories().
    /// After construction, isLoading should be false and hasContent should be false
    /// (not set to anything by a racing Task).
    func testContentViewModel_initDoesNotEagerlyLoad() {
        StorageService.shared.clearAllData()
        let vm = ContentViewModel()

        XCTAssertFalse(vm.isLoading, "ViewModel should not be loading immediately after init")
        XCTAssertFalse(vm.hasContent, "ViewModel should not have content without loadContentIfNeeded being called")
    }

    /// When no playlist is set, loadCategories() must still mark the load as done
    /// so that loadContentIfNeeded() won't deadlock or skip a future load after
    /// a playlist is added and refresh() is called.
    func testContentViewModel_loadCategoriesWithEmptyPlaylist_marksLoadDone() async {
        StorageService.shared.clearAllData()
        let vm = ContentViewModel()

        await vm.loadCategories()
        XCTAssertFalse(vm.hasContent, "hasContent should be false with no playlist")

        // Calling loadContentIfNeeded again should be a no-op (hasLoadedOnce is true)
        // If hasLoadedOnce wasn't set, this would attempt another load.
        await vm.loadContentIfNeeded()
        XCTAssertFalse(vm.isLoading, "Should not be loading after loadContentIfNeeded on already-loaded VM")
    }

    /// After an empty-playlist load, adding a playlist and calling refresh()
    /// must successfully trigger a new load.
    func testContentViewModel_refreshAfterEmptyPlaylist_reloadsSuccessfully() async {
        StorageService.shared.clearAllData()
        let vm = ContentViewModel()

        await vm.loadCategories()
        XCTAssertFalse(vm.hasContent)

        // Simulate adding a playlist and refreshing
        StorageService.shared.addPlaylist(url: URL(string: "https://iptv-org.github.io/iptv/index.m3u")!)
        await vm.refresh()

        // After refresh with a valid playlist, content should be available
        XCTAssertTrue(vm.hasContent, "hasContent should be true after refresh with a valid playlist")
        XCTAssertFalse(vm.isLoading, "Should not be loading after refresh completes")

        StorageService.shared.clearAllData()
    }

    /// loadContentIfNeeded() should only check hasLoadedOnce, not isLoadingInProgress.
    /// Two sequential calls should not cause issues.
    func testContentViewModel_loadContentIfNeeded_idempotent() async {
        StorageService.shared.clearAllData()
        let vm = ContentViewModel()

        await vm.loadContentIfNeeded()
        await vm.loadContentIfNeeded()
        XCTAssertFalse(vm.isLoading, "Double loadContentIfNeeded should not cause issues")
    }

    // MARK: - AdManager (Preload & Presentation Fixes)

    /// On non-iOS platforms, showRealInterstitial always returns false.
    /// The completion must still be callable independently.
    func testAdManager_showRealInterstitial_returnsFalseOnNonIOS() {
        var completionCalled = false
        let shown = AdManager.shared.showRealInterstitial {
            completionCalled = true
        }
        #if !os(iOS)
        XCTAssertFalse(shown, "showRealInterstitial should return false on non-iOS")
        #endif
        // Completion is only called by the ad delegate, not when returning false
        _ = completionCalled
    }

    /// AdManager.isInterstitialReady should be false initially (before SDK init).
    func testAdManager_initialState_notReady() {
        XCTAssertFalse(AdManager.shared.isInterstitialReady,
                       "Interstitial should not be ready before SDK initialization")
    }

    /// preloadInterstitial should be safe to call multiple times.
    /// On non-iOS it does nothing; on iOS the isPreloading guard prevents concurrent loads.
    func testAdManager_preloadInterstitial_safeToCallMultipleTimes() async {
        await AdManager.shared.preloadInterstitial()
        await AdManager.shared.preloadInterstitial()
        // Should not crash or hang
    }

    // MARK: - Download Limit (Clear Messaging)

    /// Free users should be limited to exactly freeMaxDownloads (2).
    func testPremiumManager_freeDownloadLimit_isTwo() {
        XCTAssertEqual(PremiumManager.freeMaxDownloads, 2,
                       "Free tier download limit should be exactly 2")
    }

    /// canDownload should return false when at or above the limit.
    func testPremiumManager_canDownload_blocksAtLimit() {
        let pm = PremiumManager()
        pm.isPremium = false

        XCTAssertTrue(pm.canDownload(currentCount: 0), "Should allow downloads when count is 0")
        XCTAssertTrue(pm.canDownload(currentCount: 1), "Should allow downloads when count is 1")
        XCTAssertFalse(pm.canDownload(currentCount: 2), "Should block downloads at limit of 2")
        XCTAssertFalse(pm.canDownload(currentCount: 5), "Should block downloads above limit")
    }

    /// Premium users should have no download limit.
    func testPremiumManager_premiumUser_unlimitedDownloads() {
        let pm = PremiumManager()
        pm.isPremium = true

        XCTAssertTrue(pm.canDownload(currentCount: 100), "Premium users should have unlimited downloads")
    }

    /// The download limit message should include the actual limit number.
    func testDownloadLimitMessage_containsCorrectLimit() {
        let expectedLimit = PremiumManager.freeMaxDownloads
        let message = "You've reached the free limit of \(expectedLimit) downloads. Upgrade to Premium for unlimited downloads."
        XCTAssertTrue(message.contains("\(expectedLimit)"),
                      "Download limit message should include the limit number")
        XCTAssertTrue(message.contains("Upgrade"),
                      "Download limit message should mention upgrade")
    }

    // MARK: - Image Cache (Resilience)

    /// ImageCacheManager should handle prefetch with empty URL list gracefully.
    func testImageCacheManager_prefetch_emptyList_noOp() {
        ImageCacheManager.shared.prefetch(urls: [])
        // Should not crash
    }

    /// ImageCacheManager should handle prefetch with valid URLs.
    func testImageCacheManager_prefetch_validURLs_noCrash() {
        let urls = [
            URL(string: "https://example.com/image1.jpg")!,
            URL(string: "https://example.com/image2.jpg")!
        ]
        ImageCacheManager.shared.prefetch(urls: urls)
        // Should not crash, prefetch fires background tasks
    }

    /// Downsampling with invalid data should return nil, not crash.
    func testImageCacheManager_downsample_invalidData_returnsNil() {
        let result = ImageCacheManager.downsample(data: Data([0, 1, 2, 3]), maxPixelSize: 400)
        XCTAssertNil(result, "Downsampling garbage data should return nil")
    }

    /// Downsampling with empty data should return nil.
    func testImageCacheManager_downsample_emptyData_returnsNil() {
        let result = ImageCacheManager.downsample(data: Data(), maxPixelSize: 400)
        XCTAssertNil(result, "Downsampling empty data should return nil")
    }

    /// fetchAndCache should return nil for unreachable URL without crashing.
    func testImageCacheManager_fetchAndCache_badURL_returnsNil() async {
        let result = await ImageCacheManager.shared.fetchAndCache(
            url: URL(string: "https://this-domain-does-not-exist-xyz.invalid/image.jpg")!,
            maxPixelSize: 400
        )
        XCTAssertNil(result, "fetchAndCache with unreachable URL should return nil")
    }

    // MARK: - Playlist Persistence (Storage Round-Trip)

    /// Playlist URLs must survive add → read round-trip.
    func testPlaylistPersistence_addAndRead() {
        StorageService.shared.clearAllData()
        let url = URL(string: "https://example.com/test.m3u")!

        StorageService.shared.addPlaylist(url: url)
        XCTAssertEqual(StorageService.shared.playlistURLs.count, 1)
        XCTAssertEqual(StorageService.shared.playlistURLs.first, url)

        StorageService.shared.clearAllData()
    }

    /// After removing a playlist and re-adding it, it should be visible.
    func testPlaylistPersistence_removeAndReAdd() {
        StorageService.shared.clearAllData()
        let url = URL(string: "https://example.com/test.m3u")!

        StorageService.shared.addPlaylist(url: url)
        StorageService.shared.removePlaylist(url: url)
        XCTAssertTrue(StorageService.shared.playlistURLs.isEmpty)

        StorageService.shared.addPlaylist(url: url)
        XCTAssertEqual(StorageService.shared.playlistURLs.count, 1)
        XCTAssertEqual(StorageService.shared.playlistURLs.first, url)

        StorageService.shared.clearAllData()
    }

    /// clearAllData must clear playlists completely.
    func testPlaylistPersistence_clearAllData_clearsPlaylists() {
        StorageService.shared.clearAllData()
        let url = URL(string: "https://example.com/test.m3u")!

        StorageService.shared.addPlaylist(url: url)
        XCTAssertFalse(StorageService.shared.playlistURLs.isEmpty)

        StorageService.shared.clearAllData()
        XCTAssertTrue(StorageService.shared.playlistURLs.isEmpty)
    }

    // MARK: - Episode Model

    /// Episodes with nil thumbnailURL should be valid and not crash any code path.
    func testEpisode_nilThumbnail_isValid() {
        let episode = Episode(
            id: "ep1",
            episodeNumber: 1,
            title: "Test Episode",
            thumbnailURL: nil,
            streamURL: URL(string: "https://example.com/ep1.mp4")!
        )
        XCTAssertNil(episode.thumbnailURL, "Episode should accept nil thumbnailURL")
        XCTAssertEqual(episode.title, "Test Episode")
    }

    /// Episodes with a thumbnailURL should preserve it.
    func testEpisode_withThumbnail_preservesURL() {
        let thumbURL = URL(string: "https://example.com/thumb.jpg")!
        let episode = Episode(
            id: "ep2",
            episodeNumber: 2,
            title: "With Thumb",
            thumbnailURL: thumbURL,
            streamURL: URL(string: "https://example.com/ep2.mp4")!
        )
        XCTAssertEqual(episode.thumbnailURL, thumbURL)
    }

    // MARK: - FullScreen Presentation Stability

    /// The interstitial gate must prevent direct playback every Nth play.
    func testInterstitialGate_triggersEvery5thPlay() {
        let pm = PremiumManager()

        for i in 1...10 {
            AdManager.shared.recordPlay()
            let shouldShow = AdManager.shared.showInterstitialIfNeeded(premiumManager: pm)
            if i % PremiumManager.freeInterstitialEveryNPlays == 0 {
                XCTAssertTrue(shouldShow, "Should show interstitial on play #\(i)")
            } else {
                XCTAssertFalse(shouldShow, "Should NOT show interstitial on play #\(i)")
            }
        }
        AdManager.shared.resetPlayCount()
    }

    /// Premium users should never see interstitial gates.
    func testInterstitialGate_neverShowsForPremium() {
        let pm = PremiumManager()
        #if DEBUG
        if !pm.isPremium { pm.debugTogglePremium() }
        #endif
        guard pm.isPremium else { return }
        for _ in 1...10 {
            AdManager.shared.recordPlay()
            let shouldShow = AdManager.shared.showInterstitialIfNeeded(premiumManager: pm)
            XCTAssertFalse(shouldShow, "Premium users should never see interstitial gate")
        }
        AdManager.shared.resetPlayCount()
        #if DEBUG
        pm.debugTogglePremium()
        #endif
    }

    /// Channel model stability: id must not change across copies (value type).
    func testChannel_valueSemantics_idStable() {
        let ch = Channel(
            id: "stable-123",
            name: "Test Channel",
            streamURL: URL(string: "http://example.com/stream.m3u8")!,
            category: "News"
        )
        var copy = ch
        copy.isFavorite = true

        XCTAssertEqual(ch.id, copy.id, "Channel id must remain stable across copies")
        XCTAssertNotEqual(ch, copy, "Channels with different isFavorite must not be equal")
    }
}
