import XCTest
@testable import EasyIpTv

@MainActor
final class ContentViewModelTests: XCTestCase {
    
    var vm: ContentViewModel!
    
    override func setUp() {
        super.setUp()
        vm = ContentViewModel()
    }
    
    override func tearDown() {
        vm = nil
        super.tearDown()
    }
    
    // MARK: - Test Helpers
    
    private func makeChannel(id: String, name: String, category: String, number: Int? = nil) -> Channel {
        Channel(
            id: id,
            name: name,
            streamURL: URL(string: "http://example.com/\(id).m3u8")!,
            category: category,
            channelNumber: number
        )
    }
    
    private func makeMovie(id: String, title: String, category: String) -> Movie {
        Movie(
            id: id,
            title: title,
            streamURL: URL(string: "http://example.com/\(id).mp4")!,
            category: category
        )
    }
    
    private func makeShow(id: String, title: String, category: String, seasons: [Season] = []) -> Show {
        Show(id: id, title: title, category: category, seasons: seasons)
    }
    
    private func makeEpisode(id: String, number: Int, title: String) -> Episode {
        Episode(
            id: id,
            episodeNumber: number,
            title: title,
            streamURL: URL(string: "http://example.com/\(id).mp4")!
        )
    }
    
    // MARK: - nextChannel / previousChannel
    
    func testNextChannelWrapsAround() {
        let ch1 = makeChannel(id: "1", name: "Ch1", category: "News")
        let ch2 = makeChannel(id: "2", name: "Ch2", category: "News")
        let ch3 = makeChannel(id: "3", name: "Ch3", category: "News")
        vm.setCachesForTesting(channelCache: ["News": [ch1, ch2, ch3]])
        
        XCTAssertEqual(vm.nextChannel(after: ch1)?.id, "2")
        XCTAssertEqual(vm.nextChannel(after: ch2)?.id, "3")
        XCTAssertEqual(vm.nextChannel(after: ch3)?.id, "1")
    }
    
    func testPreviousChannelWrapsAround() {
        let ch1 = makeChannel(id: "1", name: "Ch1", category: "News")
        let ch2 = makeChannel(id: "2", name: "Ch2", category: "News")
        let ch3 = makeChannel(id: "3", name: "Ch3", category: "News")
        vm.setCachesForTesting(channelCache: ["News": [ch1, ch2, ch3]])
        
        XCTAssertEqual(vm.previousChannel(before: ch2)?.id, "1")
        XCTAssertEqual(vm.previousChannel(before: ch1)?.id, "3")
        XCTAssertEqual(vm.previousChannel(before: ch3)?.id, "2")
    }
    
    func testNextChannelReturnsNilForUnknown() {
        let ch = makeChannel(id: "unknown", name: "Unknown", category: "News")
        vm.setCachesForTesting(channelCache: ["News": []])
        XCTAssertNil(vm.nextChannel(after: ch))
    }
    
    // MARK: - nearbyChannels
    
    func testNearbyChannels() {
        var channels: [Channel] = []
        for i in 0..<10 {
            channels.append(makeChannel(id: "\(i)", name: "Ch\(i)", category: "Sports", number: i))
        }
        vm.setCachesForTesting(channelCache: ["Sports": channels])
        
        let nearby = vm.nearbyChannels(around: channels[5], count: 5)
        XCTAssertEqual(nearby.count, 5)
        XCTAssertTrue(nearby.contains(where: { $0.id == "5" }))
    }
    
    func testNearbyChannelsWrapsAtEdge() {
        var channels: [Channel] = []
        for i in 0..<5 {
            channels.append(makeChannel(id: "\(i)", name: "Ch\(i)", category: "Sports"))
        }
        vm.setCachesForTesting(channelCache: ["Sports": channels])
        
        let nearby = vm.nearbyChannels(around: channels[0], count: 3)
        XCTAssertEqual(nearby.count, 3)
    }
    
    // MARK: - findNextEpisode
    
    func testFindNextEpisodeWithinSeason() {
        let ep1 = makeEpisode(id: "e1", number: 1, title: "Ep1")
        let ep2 = makeEpisode(id: "e2", number: 2, title: "Ep2")
        let season1 = Season(id: "s1", seasonNumber: 1, episodes: [ep1, ep2])
        let show = makeShow(id: "show1", title: "MyShow", category: "Drama", seasons: [season1])
        vm.setCachesForTesting(showCache: ["Drama": [show]])
        
        let result = vm.findNextEpisode(afterEpisodeId: "e1", inShowId: "show1")
        XCTAssertEqual(result?.episode.id, "e2")
        XCTAssertEqual(result?.seasonNumber, 1)
    }
    
    func testFindNextEpisodeAcrossSeasons() {
        let ep1 = makeEpisode(id: "e1", number: 1, title: "Ep1")
        let ep2 = makeEpisode(id: "e2", number: 1, title: "Ep1 S2")
        let season1 = Season(id: "s1", seasonNumber: 1, episodes: [ep1])
        let season2 = Season(id: "s2", seasonNumber: 2, episodes: [ep2])
        let show = makeShow(id: "show1", title: "MyShow", category: "Drama", seasons: [season1, season2])
        vm.setCachesForTesting(showCache: ["Drama": [show]])
        
        let result = vm.findNextEpisode(afterEpisodeId: "e1", inShowId: "show1")
        XCTAssertEqual(result?.episode.id, "e2")
        XCTAssertEqual(result?.seasonNumber, 2)
    }
    
    func testFindNextEpisodeReturnsNilAfterLast() {
        let ep1 = makeEpisode(id: "e1", number: 1, title: "Ep1")
        let season1 = Season(id: "s1", seasonNumber: 1, episodes: [ep1])
        let show = makeShow(id: "show1", title: "MyShow", category: "Drama", seasons: [season1])
        vm.setCachesForTesting(showCache: ["Drama": [show]])
        
        let result = vm.findNextEpisode(afterEpisodeId: "e1", inShowId: "show1")
        XCTAssertNil(result)
    }
    
    // MARK: - Lookup
    
    func testChannelWithId() {
        let ch = makeChannel(id: "abc", name: "MyChannel", category: "News")
        vm.setCachesForTesting(channelCache: ["News": [ch]])
        
        XCTAssertEqual(vm.channel(withId: "abc")?.name, "MyChannel")
        XCTAssertNil(vm.channel(withId: "nonexistent"))
    }
    
    func testMovieWithId() {
        let movie = makeMovie(id: "m1", title: "Test Movie", category: "Action")
        vm.setCachesForTesting(movieCache: ["Action": [movie]])
        
        XCTAssertEqual(vm.movie(withId: "m1")?.title, "Test Movie")
        XCTAssertNil(vm.movie(withId: "nonexistent"))
    }
    
    func testShowWithId() {
        let show = makeShow(id: "s1", title: "Test Show", category: "Comedy")
        vm.setCachesForTesting(showCache: ["Comedy": [show]])
        
        XCTAssertEqual(vm.show(withId: "s1")?.title, "Test Show")
        XCTAssertNil(vm.show(withId: "nonexistent"))
    }
    
    // MARK: - channels(in:) / movies(in:) / shows(in:)
    
    func testChannelsInCategory() {
        let ch1 = makeChannel(id: "1", name: "Ch1", category: "News")
        let ch2 = makeChannel(id: "2", name: "Ch2", category: "News")
        vm.setCachesForTesting(channelCache: ["News": [ch1, ch2]])
        
        XCTAssertEqual(vm.channels(in: "News").count, 2)
        XCTAssertEqual(vm.channels(in: "Unknown").count, 0)
    }
    
    func testAllLoadedChannels() {
        let ch1 = makeChannel(id: "1", name: "Ch1", category: "News")
        let ch2 = makeChannel(id: "2", name: "Ch2", category: "Sports")
        vm.setCachesForTesting(channelCache: ["News": [ch1], "Sports": [ch2]])
        
        XCTAssertEqual(vm.allLoadedChannels.count, 2)
    }
    
    // MARK: - findEpisode
    
    func testFindEpisodeById() {
        let ep = makeEpisode(id: "e42", number: 1, title: "Found It")
        let season = Season(id: "s1", seasonNumber: 1, episodes: [ep])
        let show = makeShow(id: "sh1", title: "Show", category: "Drama", seasons: [season])
        vm.setCachesForTesting(showCache: ["Drama": [show]])
        
        XCTAssertEqual(vm.findEpisode(byId: "e42")?.title, "Found It")
        XCTAssertNil(vm.findEpisode(byId: "nonexistent"))
    }
}
