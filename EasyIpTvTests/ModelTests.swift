import XCTest
@testable import EasyIpTv

final class ModelTests: XCTestCase {

    // MARK: - Channel.from(M3UItem)

    func testChannelFromM3UItem_mapsAllFields() {
        let logoURL = URL(string: "https://example.com/logo.png")!
        let streamURL = URL(string: "https://example.com/stream.m3u8")!
        let item = M3UItem(
            id: "ch-123",
            name: "Test Channel",
            logoURL: logoURL,
            streamURL: streamURL,
            groupTitle: "Sports",
            tvgId: "tvg-456",
            tvgName: "Test TV",
            duration: -1
        )

        let channel = Channel.from(item, channelNumber: 42)

        XCTAssertEqual(channel.id, "ch-123")
        XCTAssertEqual(channel.name, "Test Channel")
        XCTAssertEqual(channel.logoURL, logoURL)
        XCTAssertEqual(channel.streamURL, streamURL)
        XCTAssertEqual(channel.category, "Sports")
        XCTAssertEqual(channel.channelNumber, 42)
        XCTAssertEqual(channel.tvgId, "tvg-456")
    }

    // MARK: - Movie.from(M3UItem)

    func testMovieFromM3UItem_extractsYearFromTitle() {
        let streamURL = URL(string: "https://example.com/movie.mp4")!
        let item = M3UItem(
            id: "mov-1",
            name: "Inception (2010)",
            logoURL: nil,
            streamURL: streamURL,
            groupTitle: "VOD",
            duration: 8880
        )

        let movie = Movie.from(item)

        XCTAssertEqual(movie.title, "Inception")
        XCTAssertEqual(movie.year, 2010)
        XCTAssertEqual(movie.streamURL, streamURL)
        XCTAssertEqual(movie.category, "VOD")
        XCTAssertEqual(movie.posterURL, nil)
        XCTAssertEqual(movie.duration, 148) // 8880 / 60
    }

    func testMovieFromM3UItem_fallbackWhenNoYearInTitle() {
        let streamURL = URL(string: "https://example.com/movie.mp4")!
        let posterURL = URL(string: "https://example.com/poster.jpg")!
        let item = M3UItem(
            id: "mov-2",
            name: "Unknown Movie",
            logoURL: posterURL,
            streamURL: streamURL,
            groupTitle: "Movies",
            duration: 0
        )

        let movie = Movie.from(item)

        XCTAssertEqual(movie.title, "Unknown Movie")
        XCTAssertNil(movie.year)
        XCTAssertEqual(movie.streamURL, streamURL)
        XCTAssertEqual(movie.category, "Movies")
        XCTAssertEqual(movie.posterURL, posterURL)
        XCTAssertNil(movie.duration)
    }

    func testMovieFromM3UItem_verifyStreamURLCategoryPosterURL() {
        let streamURL = URL(string: "https://cdn.example.com/vod/123.mp4")!
        let posterURL = URL(string: "https://cdn.example.com/posters/123.jpg")!
        let item = M3UItem(
            id: "mov-3",
            name: "The Matrix (1999)",
            logoURL: posterURL,
            streamURL: streamURL,
            groupTitle: "Sci-Fi VOD",
            duration: 7260
        )

        let movie = Movie.from(item)

        XCTAssertEqual(movie.streamURL, streamURL)
        XCTAssertEqual(movie.category, "Sci-Fi VOD")
        XCTAssertEqual(movie.posterURL, posterURL)
    }

    // MARK: - Episode.from(M3UItem)

    func testEpisodeFromM3UItem_mapsAllFields() {
        let streamURL = URL(string: "https://example.com/ep1.mp4")!
        let thumbURL = URL(string: "https://example.com/thumb.jpg")!
        let item = M3UItem(
            id: "ep-1",
            name: "Pilot",
            logoURL: thumbURL,
            streamURL: streamURL,
            groupTitle: "Series",
            duration: 2640
        )

        let episode = Episode.from(item, episodeNumber: 1)

        XCTAssertEqual(episode.id, "ep-1")
        XCTAssertEqual(episode.episodeNumber, 1)
        XCTAssertEqual(episode.title, "Pilot")
        XCTAssertEqual(episode.streamURL, streamURL)
        XCTAssertEqual(episode.thumbnailURL, thumbURL)
        XCTAssertEqual(episode.duration, 44)
    }

    // MARK: - M3UItem.inferredContentType

    func testM3UItemInferredContentType_vodReturnsMovie() {
        let item = M3UItem(
            name: "Test",
            streamURL: URL(string: "http://x.com/a")!,
            groupTitle: "VOD"
        )
        XCTAssertEqual(item.inferredContentType, .movie)
    }

    func testM3UItemInferredContentType_seriesReturnsSeries() {
        let item = M3UItem(
            name: "Test",
            streamURL: URL(string: "http://x.com/a")!,
            groupTitle: "Series"
        )
        XCTAssertEqual(item.inferredContentType, .series)
    }

    func testM3UItemInferredContentType_otherReturnsLiveTV() {
        let item = M3UItem(
            name: "Test",
            streamURL: URL(string: "http://x.com/a")!,
            groupTitle: "Sports"
        )
        XCTAssertEqual(item.inferredContentType, .liveTV)
    }

    // MARK: - DownloadedItem Codable

    func testDownloadedItemCodable_encodeDecodeRoundTrip() throws {
        let item = DownloadedItem(
            id: "dl-1",
            contentType: "movie",
            title: "Test Movie",
            posterURL: URL(string: "https://example.com/poster.jpg"),
            localFileName: "dl-1.mp4",
            downloadDate: Date(timeIntervalSince1970: 1000),
            fileSize: 1_000_000,
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            showTitle: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil,
            showId: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DownloadedItem.self, from: data)

        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.contentType, item.contentType)
        XCTAssertEqual(decoded.title, item.title)
        XCTAssertEqual(decoded.posterURL, item.posterURL)
        XCTAssertEqual(decoded.localFileName, item.localFileName)
        XCTAssertEqual(decoded.downloadDate.timeIntervalSince1970, item.downloadDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.fileSize, item.fileSize)
        XCTAssertEqual(decoded.streamURL, item.streamURL)
    }

    func testDownloadedItemCodable_legacyMigrationLocalFileURLExtractsFileName() throws {
        // Simulate legacy JSON with "localFileURL" instead of "localFileName"
        // downloadDate: 0 = Jan 1 2001 (reference date) for default Date decoding
        let json = """
        {
            "id": "legacy-1",
            "contentType": "movie",
            "title": "Legacy Movie",
            "localFileURL": "file:///var/mobile/Containers/Data/Application/ABC123/Documents/downloads/legacy-1.mp4",
            "downloadDate": 0,
            "fileSize": 5000000,
            "streamURL": "https://example.com/stream.mp4"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DownloadedItem.self, from: json)

        XCTAssertEqual(decoded.localFileName, "legacy-1.mp4")
        XCTAssertEqual(decoded.id, "legacy-1")
        XCTAssertEqual(decoded.title, "Legacy Movie")
    }

    // MARK: - DownloadRetention

    func testDownloadRetentionTimeInterval() {
        XCTAssertEqual(DownloadRetention.oneWeek.timeInterval, 7 * 24 * 3600)
        XCTAssertEqual(DownloadRetention.twoWeeks.timeInterval, 14 * 24 * 3600)
        XCTAssertEqual(DownloadRetention.oneMonth.timeInterval, 30 * 24 * 3600)
        XCTAssertEqual(DownloadRetention.threeMonths.timeInterval, 90 * 24 * 3600)
    }

    // MARK: - Show.totalEpisodes

    func testShowTotalEpisodes() {
        let episode1 = Episode(episodeNumber: 1, title: "E1", streamURL: URL(string: "http://x.com/1")!)
        let episode2 = Episode(episodeNumber: 2, title: "E2", streamURL: URL(string: "http://x.com/2")!)
        let episode3 = Episode(episodeNumber: 3, title: "E3", streamURL: URL(string: "http://x.com/3")!)
        let episode4 = Episode(episodeNumber: 4, title: "E4", streamURL: URL(string: "http://x.com/4")!)
        let episode5 = Episode(episodeNumber: 5, title: "E5", streamURL: URL(string: "http://x.com/5")!)
        let episode6 = Episode(episodeNumber: 6, title: "E6", streamURL: URL(string: "http://x.com/6")!)

        let season1 = Season(seasonNumber: 1, episodes: [episode1, episode2, episode3])
        let season2 = Season(seasonNumber: 2, episodes: [episode4, episode5, episode6])

        let show = Show(title: "Test Show", category: "Drama", seasons: [season1, season2])

        XCTAssertEqual(show.totalEpisodes, 6)
    }

    // MARK: - Array extensions on Channel

    func testChannelGroupedByCategory() {
        let ch1 = Channel(name: "A", streamURL: URL(string: "http://a.com")!, category: "Sports")
        let ch2 = Channel(name: "B", streamURL: URL(string: "http://b.com")!, category: "News")
        let ch3 = Channel(name: "C", streamURL: URL(string: "http://c.com")!, category: "Sports")

        let grouped = [ch1, ch2, ch3].groupedByCategory

        XCTAssertEqual(grouped["Sports"]?.count, 2)
        XCTAssertEqual(grouped["News"]?.count, 1)
    }

    func testChannelFavorites() {
        let ch1 = Channel(name: "A", streamURL: URL(string: "http://a.com")!, category: "X", isFavorite: true)
        let ch2 = Channel(name: "B", streamURL: URL(string: "http://b.com")!, category: "X", isFavorite: false)
        let ch3 = Channel(name: "C", streamURL: URL(string: "http://c.com")!, category: "X", isFavorite: true)

        let favs = [ch1, ch2, ch3].favorites

        XCTAssertEqual(favs.count, 2)
        XCTAssertTrue(favs.allSatisfy { $0.isFavorite })
    }

    func testChannelSortedByNumber() {
        let ch1 = Channel(name: "Third", streamURL: URL(string: "http://a.com")!, category: "X", channelNumber: 30)
        let ch2 = Channel(name: "First", streamURL: URL(string: "http://b.com")!, category: "X", channelNumber: 10)
        let ch3 = Channel(name: "Second", streamURL: URL(string: "http://c.com")!, category: "X", channelNumber: 20)
        let ch4 = Channel(name: "NoNum", streamURL: URL(string: "http://d.com")!, category: "X", channelNumber: nil)

        let sorted = [ch1, ch2, ch3, ch4].sortedByNumber

        XCTAssertEqual(sorted[0].name, "First")
        XCTAssertEqual(sorted[1].name, "Second")
        XCTAssertEqual(sorted[2].name, "Third")
        XCTAssertEqual(sorted[3].name, "NoNum") // nil -> Int.max, so last
    }
}
