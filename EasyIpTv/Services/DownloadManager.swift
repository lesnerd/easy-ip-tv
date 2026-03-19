import Foundation
import Combine

struct DownloadedItem: Codable, Identifiable {
    let id: String
    let contentType: String // "movie" or "episode"
    let title: String
    let posterURL: URL?
    /// Filename only (e.g. "abc123.mp4") — the full path is resolved at runtime
    /// because the app container path changes between launches on iOS.
    let localFileName: String
    let downloadDate: Date
    let fileSize: Int64
    let streamURL: URL
    let showTitle: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeTitle: String?
    let showId: String?
    
    var localFileURL: URL {
        DownloadManager.downloadsDirectory.appendingPathComponent(localFileName)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, contentType, title, posterURL, localFileName, downloadDate
        case fileSize, streamURL, showTitle, seasonNumber, episodeNumber
        case episodeTitle, showId
        // Legacy key for migration
        case localFileURL
    }
    
    init(id: String, contentType: String, title: String, posterURL: URL?,
         localFileName: String, downloadDate: Date, fileSize: Int64,
         streamURL: URL, showTitle: String?, seasonNumber: Int?,
         episodeNumber: Int?, episodeTitle: String?, showId: String?) {
        self.id = id; self.contentType = contentType; self.title = title
        self.posterURL = posterURL; self.localFileName = localFileName
        self.downloadDate = downloadDate; self.fileSize = fileSize
        self.streamURL = streamURL; self.showTitle = showTitle
        self.seasonNumber = seasonNumber; self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle; self.showId = showId
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        contentType = try c.decode(String.self, forKey: .contentType)
        title = try c.decode(String.self, forKey: .title)
        posterURL = try c.decodeIfPresent(URL.self, forKey: .posterURL)
        downloadDate = try c.decode(Date.self, forKey: .downloadDate)
        fileSize = try c.decode(Int64.self, forKey: .fileSize)
        streamURL = try c.decode(URL.self, forKey: .streamURL)
        showTitle = try c.decodeIfPresent(String.self, forKey: .showTitle)
        seasonNumber = try c.decodeIfPresent(Int.self, forKey: .seasonNumber)
        episodeNumber = try c.decodeIfPresent(Int.self, forKey: .episodeNumber)
        episodeTitle = try c.decodeIfPresent(String.self, forKey: .episodeTitle)
        showId = try c.decodeIfPresent(String.self, forKey: .showId)
        
        if let name = try c.decodeIfPresent(String.self, forKey: .localFileName) {
            localFileName = name
        } else if let legacyURL = try c.decodeIfPresent(URL.self, forKey: .localFileURL) {
            localFileName = legacyURL.lastPathComponent
        } else {
            localFileName = "\(id).mp4"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(contentType, forKey: .contentType)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(posterURL, forKey: .posterURL)
        try c.encode(localFileName, forKey: .localFileName)
        try c.encode(downloadDate, forKey: .downloadDate)
        try c.encode(fileSize, forKey: .fileSize)
        try c.encode(streamURL, forKey: .streamURL)
        try c.encodeIfPresent(showTitle, forKey: .showTitle)
        try c.encodeIfPresent(seasonNumber, forKey: .seasonNumber)
        try c.encodeIfPresent(episodeNumber, forKey: .episodeNumber)
        try c.encodeIfPresent(episodeTitle, forKey: .episodeTitle)
        try c.encodeIfPresent(showId, forKey: .showId)
    }
}

struct DownloadProgress {
    var fractionCompleted: Double
    var totalBytesWritten: Int64
    var totalBytesExpectedToWrite: Int64
}

enum DownloadRetention: String, Codable, CaseIterable, Identifiable {
    case oneWeek = "1w"
    case twoWeeks = "2w"
    case oneMonth = "1m"
    case threeMonths = "3m"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .oneWeek: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .oneWeek: return 7 * 24 * 3600
        case .twoWeeks: return 14 * 24 * 3600
        case .oneMonth: return 30 * 24 * 3600
        case .threeMonths: return 90 * 24 * 3600
        }
    }
}

@MainActor
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloads: [DownloadedItem] = []
    @Published var activeDownloads: [String: DownloadProgress] = [:]
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var downloadContentMap: [Int: DownloadRequest] = [:] // taskIdentifier -> request
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private struct DownloadRequest {
        let id: String
        let contentType: String
        let title: String
        let posterURL: URL?
        let streamURL: URL
        let showTitle: String?
        let seasonNumber: Int?
        let episodeNumber: Int?
        let episodeTitle: String?
        let showId: String?
    }
    
    nonisolated static var downloadsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("downloads", isDirectory: true)
    }
    
    override init() {
        super.init()
        ensureDownloadsDirectory()
        loadDownloads()
    }
    
    private func ensureDownloadsDirectory() {
        try? FileManager.default.createDirectory(
            at: Self.downloadsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private func loadDownloads() {
        downloads = StorageService.shared.getDownloads()
        NSLog("[DownloadManager] Loaded %d downloads from storage", downloads.count)
        pruneOrphanedFiles()
    }
    
    private func saveDownloads() {
        NSLog("[DownloadManager] Saving %d downloads to storage", downloads.count)
        StorageService.shared.saveDownloads(downloads)
    }
    
    private func pruneOrphanedFiles() {
        var validItems: [DownloadedItem] = []
        for item in downloads {
            if FileManager.default.fileExists(atPath: item.localFileURL.path) {
                validItems.append(item)
            }
        }
        if validItems.count != downloads.count {
            downloads = validItems
            saveDownloads()
        }
    }
    
    // MARK: - Public API
    
    func startDownload(movie: Movie) {
        let id = movie.id
        guard !isDownloaded(id: id), activeDownloads[id] == nil else { return }
        
        let request = DownloadRequest(
            id: id,
            contentType: "movie",
            title: movie.title,
            posterURL: movie.posterURL,
            streamURL: movie.streamURL,
            showTitle: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            episodeTitle: nil,
            showId: nil
        )
        beginDownload(request: request)
    }
    
    func startDownload(episode: Episode, showTitle: String, showId: String, seasonNumber: Int) {
        let id = episode.id
        guard !isDownloaded(id: id), activeDownloads[id] == nil else { return }
        
        let request = DownloadRequest(
            id: id,
            contentType: "episode",
            title: episode.title,
            posterURL: episode.thumbnailURL,
            streamURL: episode.streamURL,
            showTitle: showTitle,
            seasonNumber: seasonNumber,
            episodeNumber: episode.episodeNumber,
            episodeTitle: episode.title,
            showId: showId
        )
        beginDownload(request: request)
    }
    
    func cancelDownload(id: String) {
        if let task = downloadTasks[id] {
            task.cancel()
            downloadTasks.removeValue(forKey: id)
        }
        activeDownloads.removeValue(forKey: id)
    }
    
    func deleteDownload(id: String) {
        if let index = downloads.firstIndex(where: { $0.id == id }) {
            let item = downloads[index]
            try? FileManager.default.removeItem(at: item.localFileURL)
            downloads.remove(at: index)
            saveDownloads()
        }
    }
    
    func isDownloaded(id: String) -> Bool {
        downloads.contains(where: { $0.id == id })
    }
    
    func isDownloading(id: String) -> Bool {
        activeDownloads[id] != nil
    }
    
    func localURL(for id: String) -> URL? {
        guard let item = downloads.first(where: { $0.id == id }),
              FileManager.default.fileExists(atPath: item.localFileURL.path) else {
            return nil
        }
        return item.localFileURL
    }
    
    func downloadedItem(for id: String) -> DownloadedItem? {
        downloads.first(where: { $0.id == id })
    }
    
    var totalDownloadCount: Int {
        downloads.count + activeDownloads.count
    }
    
    // MARK: - Cleanup
    
    func performCleanup() {
        let retention = StorageService.shared.getDownloadRetention()
        let cutoff = Date().addingTimeInterval(-retention.timeInterval)
        
        var removedCount = 0
        downloads = downloads.filter { item in
            if item.downloadDate < cutoff {
                try? FileManager.default.removeItem(at: item.localFileURL)
                removedCount += 1
                return false
            }
            return true
        }
        
        if removedCount > 0 {
            saveDownloads()
            NSLog("[DownloadManager] Cleaned up %d expired downloads", removedCount)
        }
    }
    
    // MARK: - Private
    
    private func beginDownload(request: DownloadRequest) {
        let task = urlSession.downloadTask(with: request.streamURL)
        downloadTasks[request.id] = task
        downloadContentMap[task.taskIdentifier] = request
        activeDownloads[request.id] = DownloadProgress(
            fractionCompleted: 0,
            totalBytesWritten: 0,
            totalBytesExpectedToWrite: 0
        )
        task.resume()
        NSLog("[DownloadManager] Started download: %@ (%@)", request.title, request.id)
    }
    
    private func fileExtension(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let known = ["mp4", "mkv", "avi", "ts", "m3u8", "mov", "webm",
                     "flv", "wmv", "mpg", "mpeg", "m4v", "3gp", "ogv", "vob"]
        return known.contains(ext) ? ext : "mp4"
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier

        // Must read request from map synchronously — use a lock-free approach
        // by capturing what we need before any async dispatch.
        // Since downloadContentMap is MainActor-isolated, we need to copy the
        // file first (it's deleted when this method returns), then update state.
        let downloadsDir = Self.downloadsDirectory
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        // Copy the temp file to a staging location immediately (before it's deleted)
        let stagingURL = downloadsDir.appendingPathComponent("staging-\(taskId).tmp")
        do {
            if FileManager.default.fileExists(atPath: stagingURL.path) {
                try FileManager.default.removeItem(at: stagingURL)
            }
            try FileManager.default.moveItem(at: location, to: stagingURL)
        } catch {
            NSLog("[DownloadManager] Failed to stage downloaded file: %@", error.localizedDescription)
            return
        }

        Task { @MainActor in
            guard let request = self.downloadContentMap[taskId] else {
                NSLog("[DownloadManager] No request found for task %d", taskId)
                try? FileManager.default.removeItem(at: stagingURL)
                return
            }

            let ext = self.fileExtension(from: request.streamURL)
            let destURL = downloadsDir.appendingPathComponent("\(request.id).\(ext)")

            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: stagingURL, to: destURL)

                let attrs = try FileManager.default.attributesOfItem(atPath: destURL.path)
                let fileSize = attrs[.size] as? Int64 ?? 0

                let item = DownloadedItem(
                    id: request.id,
                    contentType: request.contentType,
                    title: request.title,
                    posterURL: request.posterURL,
                    localFileName: destURL.lastPathComponent,
                    downloadDate: Date(),
                    fileSize: fileSize,
                    streamURL: request.streamURL,
                    showTitle: request.showTitle,
                    seasonNumber: request.seasonNumber,
                    episodeNumber: request.episodeNumber,
                    episodeTitle: request.episodeTitle,
                    showId: request.showId
                )

                self.downloads.insert(item, at: 0)
                self.saveDownloads()

                NSLog("[DownloadManager] Download complete: %@ (%.1f MB)", request.title, Double(fileSize) / 1_000_000)
            } catch {
                NSLog("[DownloadManager] Failed to move file: %@", error.localizedDescription)
            }

            self.activeDownloads.removeValue(forKey: request.id)
            self.downloadTasks.removeValue(forKey: request.id)
            self.downloadContentMap.removeValue(forKey: taskId)
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskId = downloadTask.taskIdentifier
        
        Task { @MainActor in
            guard let request = downloadContentMap[taskId] else { return }
            let fraction = totalBytesExpectedToWrite > 0
                ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                : 0
            activeDownloads[request.id] = DownloadProgress(
                fractionCompleted: fraction,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }
        let taskId = task.taskIdentifier
        
        Task { @MainActor in
            if let request = downloadContentMap[taskId] {
                NSLog("[DownloadManager] Download failed: %@ — %@", request.title, error.localizedDescription)
                activeDownloads.removeValue(forKey: request.id)
                downloadTasks.removeValue(forKey: request.id)
            }
            downloadContentMap.removeValue(forKey: taskId)
        }
    }
}
