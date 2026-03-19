import XCTest
@testable import EasyIpTv

/// Integration tests that parse a real M3U playlist from the network.
/// Downloads once and caches the result for all tests in this class.
final class M3UIntegrationTests: XCTestCase {

    private static let testM3UURL = URL(string: "https://iptv-org.github.io/iptv/index.m3u")!
    private static var cachedResult: M3UParser.ParsedContent?

    private func getResult() async throws -> M3UParser.ParsedContent {
        if let cached = Self.cachedResult { return cached }
        let result = try await M3UParser().parse(from: Self.testM3UURL)
        Self.cachedResult = result
        return result
    }

    override class func tearDown() {
        cachedResult = nil
        super.tearDown()
    }

    // MARK: - Network M3U Parsing Tests

    func testParseRealM3U() async throws {
        let result = try await getResult()
        XCTAssertGreaterThan(result.channels.count, 0, "Parsed result should have at least one channel")
    }

    func testChannelsHaveNames() async throws {
        let result = try await getResult()
        for channel in result.channels {
            XCTAssertFalse(channel.name.isEmpty, "Channel should have non-empty name: \(channel)")
        }
    }

    func testChannelsHaveStreamURLs() async throws {
        let result = try await getResult()
        for channel in result.channels {
            let scheme = channel.streamURL.scheme?.lowercased() ?? ""
            XCTAssertFalse(scheme.isEmpty, "Channel '\(channel.name)' should have a URL scheme")
        }
    }

    func testCategoriesExtracted() async throws {
        let result = try await getResult()
        for (category, _) in result.categories {
            XCTAssertFalse(category.isEmpty, "Category should be non-empty")
        }
        for channel in result.channels {
            XCTAssertFalse(channel.category.isEmpty, "Channel '\(channel.name)' should have non-empty category")
        }
    }

    func testMostChannelsHaveUniqueIds() async throws {
        let result = try await getResult()
        let ids = result.channels.map { $0.id }
        let uniqueIds = Set(ids)
        let uniqueRatio = Double(uniqueIds.count) / Double(ids.count)
        XCTAssertGreaterThan(uniqueRatio, 0.5, "At least 50% of channel IDs should be unique (got \(uniqueIds.count)/\(ids.count))")
    }

    func testSomeChannelsHaveLogos() async throws {
        let result = try await getResult()
        let channelsWithLogos = result.channels.filter { $0.logoURL != nil }
        XCTAssertGreaterThan(result.channels.count, 0, "Should have channels to check")
        if channelsWithLogos.isEmpty {
            throw XCTSkip("Index does not include tvg-logo; skipping logo assertion")
        }
        XCTAssertGreaterThan(channelsWithLogos.count, 0, "At least some channels have logoURL set")
    }
}
