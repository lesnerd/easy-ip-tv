import XCTest
@testable import EasyIpTv

@MainActor
final class DownloadManagerTests: XCTestCase {

    var downloadManager: DownloadManager!
    var storage: StorageService!

    override func setUp() async throws {
        try await super.setUp()
        downloadManager = DownloadManager.shared
        storage = StorageService.shared
        storage.clearAllData()
        storage.saveDownloads([])
        downloadManager.downloads = []
        downloadManager.activeDownloads = [:]
    }

    override func tearDown() async throws {
        downloadManager.downloads = []
        downloadManager.activeDownloads = [:]
        storage.saveDownloads([])
        storage.clearAllData()
        try await super.tearDown()
    }

    // MARK: - 1. fileExtension - private, test indirectly via download completion (skip per spec)

    // fileExtension(from:) is private - tested indirectly through download flow. Skipping direct test.

    // MARK: - 2. isDownloaded / isDownloading

    func testIsDownloaded_returnsFalseForUnknownId() {
        XCTAssertFalse(downloadManager.isDownloaded(id: "unknown-id-12345"))
    }

    func testIsDownloading_returnsFalseForUnknownId() {
        XCTAssertFalse(downloadManager.isDownloading(id: "unknown-id-12345"))
    }

    // MARK: - 3. localURL

    func testLocalURL_returnsNilForUnknownId() {
        XCTAssertNil(downloadManager.localURL(for: "unknown-id-12345"))
    }

    // MARK: - 4. DownloadedItem.localFileURL

    func testDownloadedItem_localFileURLEndsWithDownloadsPath() {
        let item = DownloadedItem(
            id: "test-id",
            contentType: "movie",
            title: "Test",
            posterURL: nil,
            localFileName: "test.mp4",
            downloadDate: Date(),
            fileSize: 1000,
            streamURL: URL(string: "https://example.com/s.mp4")!,
            showTitle: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil,
            showId: nil
        )
        let url = item.localFileURL
        XCTAssertTrue(url.path.hasSuffix("downloads/test.mp4") || url.lastPathComponent == "test.mp4")
    }

    // MARK: - 5. performCleanup

    func testPerformCleanup_removesExpiredDownloads() throws {
        let downloadsDir = DownloadManager.downloadsDirectory
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let oldDate = Date().addingTimeInterval(-14 * 24 * 3600) // 2 weeks ago
        let fileName = "cleanup-test-\(UUID().uuidString).mp4"
        let fileURL = downloadsDir.appendingPathComponent(fileName)

        // Create a real file
        try Data("test".utf8).write(to: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let item = DownloadedItem(
            id: "cleanup-item",
            contentType: "movie",
            title: "Old Download",
            posterURL: nil,
            localFileName: fileName,
            downloadDate: oldDate,
            fileSize: 4,
            streamURL: URL(string: "https://example.com/old.mp4")!,
            showTitle: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil,
            showId: nil
        )

        storage.saveDownloadRetention(.oneWeek)
        downloadManager.downloads = [item]

        downloadManager.performCleanup()

        XCTAssertTrue(downloadManager.downloads.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - 6. totalDownloadCount

    func testTotalDownloadCount_equalsDownloadsPlusActiveDownloads() {
        let item = DownloadedItem(
            id: "count-item",
            contentType: "movie",
            title: "Count Test",
            posterURL: nil,
            localFileName: "count.mp4",
            downloadDate: Date(),
            fileSize: 100,
            streamURL: URL(string: "https://example.com/c.mp4")!,
            showTitle: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil,
            showId: nil
        )
        downloadManager.downloads = [item]
        downloadManager.activeDownloads = ["active-1": DownloadProgress(fractionCompleted: 0.5, totalBytesWritten: 100, totalBytesExpectedToWrite: 200)]

        XCTAssertEqual(downloadManager.totalDownloadCount, 2)
    }
}
