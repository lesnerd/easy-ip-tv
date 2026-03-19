import XCTest
@testable import EasyIpTv

/// Integration tests for ContentViewModel loading from a real M3U playlist.
/// Loads once and caches the ViewModel for all tests in this class.
@MainActor
final class ContentLoadingTests: XCTestCase {

    private static let testM3UURL = URL(string: "https://iptv-org.github.io/iptv/index.m3u")!
    nonisolated(unsafe) private static var sharedVM: ContentViewModel?
    nonisolated(unsafe) private static var setupDone = false

    private func getLoadedVM() async -> ContentViewModel {
        if let vm = Self.sharedVM { return vm }
        StorageService.shared.clearAllData()
        StorageService.shared.addPlaylist(url: Self.testM3UURL)
        let vm = ContentViewModel()
        await vm.loadCategories()
        Self.sharedVM = vm
        Self.setupDone = true
        return vm
    }

    override class func tearDown() {
        if setupDone {
            sharedVM = nil
            setupDone = false
        }
        super.tearDown()
    }

    func testLoadCategories() async {
        let viewModel = await getLoadedVM()
        XCTAssertFalse(viewModel.liveCategories.isEmpty, "liveCategories should be populated after loading")
    }

    func testHasContent() async {
        let viewModel = await getLoadedVM()
        XCTAssertTrue(viewModel.hasContent, "hasContent should be true after loading")
    }

    func testChannelsPopulated() async {
        let viewModel = await getLoadedVM()
        guard let firstCategory = viewModel.liveCategories.first else {
            XCTFail("Should have at least one live category")
            return
        }
        let channels = viewModel.channels(in: firstCategory.name)
        XCTAssertFalse(channels.isEmpty, "Channels for first category should be populated")
    }

    func testLoadTrendingContent() async {
        let viewModel = await getLoadedVM()
        await viewModel.loadTrendingContent()
        XCTAssertFalse(viewModel.trendingChannels.isEmpty, "trendingChannels should be populated after loadTrendingContent")
    }
}
