import XCTest
@testable import EasyIpTv

@MainActor
final class StorageServiceTests: XCTestCase {

    var storage: StorageService!

    override func setUp() async throws {
        try await super.setUp()
        storage = StorageService.shared
        storage.clearAllData()
    }

    override func tearDown() async throws {
        storage.clearAllData()
        try await super.tearDown()
    }

    // MARK: - 1. Favorites (ID-based)

    func testToggleFavorite_channelId_togglesOnThenOff() {
        let channelId = "ch-1"
        XCTAssertFalse(storage.isFavorite(channelId: channelId))

        storage.toggleFavorite(channelId: channelId)
        XCTAssertTrue(storage.isFavorite(channelId: channelId))

        storage.toggleFavorite(channelId: channelId)
        XCTAssertFalse(storage.isFavorite(channelId: channelId))
    }

    func testIsFavorite_channelMovieShow() {
        storage.addFavorites(channelIds: ["ch-1"])
        storage.toggleFavorite(movieId: "mov-1")
        storage.toggleFavorite(showId: "show-1")

        XCTAssertTrue(storage.isFavorite(channelId: "ch-1"))
        XCTAssertTrue(storage.isFavorite(movieId: "mov-1"))
        XCTAssertTrue(storage.isFavorite(showId: "show-1"))

        XCTAssertFalse(storage.isFavorite(channelId: "ch-unknown"))
        XCTAssertFalse(storage.isFavorite(movieId: "mov-unknown"))
        XCTAssertFalse(storage.isFavorite(showId: "show-unknown"))
    }

    func testAddFavorites_addsMultiple() {
        storage.addFavorites(channelIds: ["ch-1", "ch-2", "ch-3"])
        XCTAssertTrue(storage.isFavorite(channelId: "ch-1"))
        XCTAssertTrue(storage.isFavorite(channelId: "ch-2"))
        XCTAssertTrue(storage.isFavorite(channelId: "ch-3"))
    }

    func testRemoveFavorites_removesThem() {
        storage.addFavorites(channelIds: ["ch-1", "ch-2", "ch-3"])
        storage.removeFavorites(channelIds: ["ch-1", "ch-3"])
        XCTAssertFalse(storage.isFavorite(channelId: "ch-1"))
        XCTAssertTrue(storage.isFavorite(channelId: "ch-2"))
        XCTAssertFalse(storage.isFavorite(channelId: "ch-3"))
    }

    func testAreAllFavorites_returnsTrueOnlyWhenAllFavorited() {
        storage.addFavorites(channelIds: ["ch-1", "ch-2"])
        XCTAssertTrue(storage.areAllFavorites(channelIds: ["ch-1", "ch-2"]))
        XCTAssertFalse(storage.areAllFavorites(channelIds: ["ch-1", "ch-2", "ch-3"]))
        XCTAssertFalse(storage.areAllFavorites(channelIds: []))
    }

    // MARK: - 2. Full object favorites

    func testSaveFavoriteChannel_getFavoriteChannels_roundTrip() {
        let channel = Channel(
            id: "ch-fav",
            name: "Favorite Channel",
            streamURL: URL(string: "https://example.com/stream.m3u8")!,
            category: "Sports"
        )
        storage.saveFavoriteChannel(channel)
        let loaded = storage.getFavoriteChannels()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, channel.id)
        XCTAssertEqual(loaded[0].name, channel.name)
        XCTAssertTrue(loaded[0].isFavorite)
    }

    func testSaveFavoriteMovie_getFavoriteMovies_roundTrip() {
        let movie = Movie(
            id: "mov-fav",
            title: "Favorite Movie",
            streamURL: URL(string: "https://example.com/movie.mp4")!,
            category: "Action"
        )
        storage.saveFavoriteMovie(movie)
        let loaded = storage.getFavoriteMovies()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, movie.id)
        XCTAssertEqual(loaded[0].title, movie.title)
        XCTAssertTrue(loaded[0].isFavorite)
    }

    func testSaveFavoriteShow_getFavoriteShows_roundTrip() {
        let show = Show(
            id: "show-fav",
            title: "Favorite Show",
            category: "Drama"
        )
        storage.saveFavoriteShow(show)
        let loaded = storage.getFavoriteShows()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, show.id)
        XCTAssertEqual(loaded[0].title, show.title)
        XCTAssertTrue(loaded[0].isFavorite)
    }

    func testRemoveFavoriteChannel_removesCorrectly() {
        let channel = Channel(
            id: "ch-remove",
            name: "To Remove",
            streamURL: URL(string: "https://example.com/s.m3u8")!,
            category: "News"
        )
        storage.saveFavoriteChannel(channel)
        XCTAssertEqual(storage.getFavoriteChannels().count, 1)
        storage.removeFavoriteChannel(id: "ch-remove")
        XCTAssertEqual(storage.getFavoriteChannels().count, 0)
    }

    // MARK: - 3. Watch progress

    func testSaveWatchProgress_getWatchProgress_roundTrip() {
        storage.saveWatchProgress(contentId: "content-1", progress: 0.42)
        XCTAssertEqual(storage.getWatchProgress(for: "content-1"), 0.42, accuracy: 0.001)
    }

    func testGetWatchProgress_unknownContent_returnsZero() {
        XCTAssertEqual(storage.getWatchProgress(for: "unknown-id"), 0.0)
    }

    func testSaveWatchProgress_overwritesExisting() {
        storage.saveWatchProgress(contentId: "content-1", progress: 0.2)
        storage.saveWatchProgress(contentId: "content-1", progress: 0.8)
        XCTAssertEqual(storage.getWatchProgress(for: "content-1"), 0.8, accuracy: 0.001)
    }

    // MARK: - 4. Playlists

    func testAddPlaylist_playlistURLs() {
        let url1 = URL(string: "https://example.com/playlist.m3u")!
        let url2 = URL(string: "https://other.com/channels.m3u8")!
        storage.addPlaylist(url: url1)
        storage.addPlaylist(url: url2)
        XCTAssertEqual(storage.playlistURLs.count, 2)
        XCTAssertTrue(storage.playlistURLs.contains(url1))
        XCTAssertTrue(storage.playlistURLs.contains(url2))
    }

    func testRemovePlaylist() {
        let url = URL(string: "https://example.com/playlist.m3u")!
        storage.addPlaylist(url: url)
        XCTAssertEqual(storage.playlistURLs.count, 1)
        storage.removePlaylist(url: url)
        XCTAssertEqual(storage.playlistURLs.count, 0)
    }

    func testAddPlaylist_noDuplicates() {
        let url = URL(string: "https://example.com/playlist.m3u")!
        storage.addPlaylist(url: url)
        storage.addPlaylist(url: url)
        XCTAssertEqual(storage.playlistURLs.count, 1)
    }

    // MARK: - 5. Continue watching

    func testSaveContinueWatching_getContinueWatching() {
        let item = StorageService.ContinueWatchingItem(
            id: "cw-1",
            contentType: "movie",
            title: "Test Movie",
            progress: 0.5,
            currentTime: 120,
            duration: 240,
            timestamp: Date(),
            showId: nil,
            episodeId: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil
        )
        storage.saveContinueWatching(item: item)
        let loaded = storage.getContinueWatching()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, item.id)
        XCTAssertEqual(loaded[0].title, item.title)
        XCTAssertEqual(loaded[0].progress, 0.5, accuracy: 0.001)
    }

    func testRemoveContinueWatching() {
        let item = StorageService.ContinueWatchingItem(
            id: "cw-remove",
            contentType: "movie",
            title: "To Remove",
            progress: 0.3,
            currentTime: 60,
            duration: 200,
            timestamp: Date(),
            showId: nil,
            episodeId: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil
        )
        storage.saveContinueWatching(item: item)
        XCTAssertEqual(storage.getContinueWatching().count, 1)
        storage.removeContinueWatching(id: "cw-remove")
        XCTAssertEqual(storage.getContinueWatching().count, 0)
    }

    func testContinueWatching_orderedByTimestampMostRecentFirst() {
        let old = StorageService.ContinueWatchingItem(
            id: "cw-old",
            contentType: "movie",
            title: "Old",
            progress: 0.2,
            currentTime: 10,
            duration: 100,
            timestamp: Date().addingTimeInterval(-3600),
            showId: nil,
            episodeId: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil
        )
        let recent = StorageService.ContinueWatchingItem(
            id: "cw-recent",
            contentType: "movie",
            title: "Recent",
            progress: 0.2,
            currentTime: 10,
            duration: 100,
            timestamp: Date(),
            showId: nil,
            episodeId: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil
        )
        storage.saveContinueWatching(item: old)
        storage.saveContinueWatching(item: recent)
        let loaded = storage.getContinueWatching()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, "cw-recent")
        XCTAssertEqual(loaded[1].id, "cw-old")
    }

    // MARK: - 6. Downloads

    func testSaveDownloads_getDownloads_roundTrip() {
        let items = [
            DownloadedItem(
                id: "dl-1",
                contentType: "movie",
                title: "Downloaded Movie",
                posterURL: nil,
                localFileName: "dl-1.mp4",
                downloadDate: Date(),
                fileSize: 1000,
                streamURL: URL(string: "https://example.com/stream.mp4")!,
                showTitle: nil,
                seasonNumber: nil,
                episodeNumber: nil,
                episodeTitle: nil,
                showId: nil
            )
        ]
        storage.saveDownloads(items)
        let loaded = storage.getDownloads()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "dl-1")
        XCTAssertEqual(loaded[0].title, "Downloaded Movie")
    }

    func testSaveDownloadRetention_getDownloadRetention() {
        storage.saveDownloadRetention(.oneMonth)
        XCTAssertEqual(storage.getDownloadRetention(), .oneMonth)
        storage.saveDownloadRetention(.threeMonths)
        XCTAssertEqual(storage.getDownloadRetention(), .threeMonths)
    }

    // MARK: - 7. Playlist type detection

    func testPlaylistType_m3u() {
        let url = URL(string: "https://example.com/playlist.m3u")!
        XCTAssertEqual(StorageService.playlistType(for: url), .m3u)
    }

    func testPlaylistType_xtreamCodes() {
        let url = URL(string: "http://server.com:8080/get.php?username=user&password=pass&type=m3u_plus")!
        XCTAssertEqual(StorageService.playlistType(for: url), .xtreamCodes)
    }

    func testPlaylistType_stalkerPortal() {
        let url = URL(string: "stalker://portal.example.com/c/?mac=00:1A:79:AB:CD:EF")!
        XCTAssertEqual(StorageService.playlistType(for: url), .stalkerPortal)
    }

    // MARK: - 8. clearAllData

    func testClearAllData_clearsFavoritesProgressPlaylists() {
        storage.addFavorites(channelIds: ["ch-1"])
        storage.saveFavoriteChannel(Channel(id: "ch-1", name: "Ch1", streamURL: URL(string: "https://x.com/s.m3u8")!, category: "Sports"))
        storage.saveWatchProgress(contentId: "c1", progress: 0.5)
        storage.addPlaylist(url: URL(string: "https://example.com/p.m3u")!)
        storage.saveContinueWatching(item: StorageService.ContinueWatchingItem(
            id: "cw-1",
            contentType: "movie",
            title: "T",
            progress: 0.1,
            currentTime: 10,
            duration: 100,
            timestamp: Date(),
            showId: nil,
            episodeId: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil
        ))

        storage.clearAllData()

        XCTAssertFalse(storage.isFavorite(channelId: "ch-1"))
        XCTAssertEqual(storage.getWatchProgress(for: "c1"), 0.0)
        XCTAssertTrue(storage.playlistURLs.isEmpty)
        XCTAssertTrue(storage.getContinueWatching().isEmpty)
        XCTAssertTrue(storage.getFavoriteChannels().isEmpty)
        XCTAssertTrue(storage.getFavoriteMovies().isEmpty)
        XCTAssertTrue(storage.getFavoriteShows().isEmpty)
    }
}
