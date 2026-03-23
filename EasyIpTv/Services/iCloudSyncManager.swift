import Foundation

/// Syncs Continue Watching data across devices via iCloud Key-Value Store.
/// Uses NSUbiquitousKeyValueStore which automatically syncs small amounts
/// of data across all devices signed into the same iCloud account.
final class iCloudSyncManager {
    static let shared = iCloudSyncManager()
    
    private let kvStore = NSUbiquitousKeyValueStore.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// Set to true while merging from cloud to prevent re-pushing
    private var isMergingFromCloud = false
    
    private enum CloudKeys {
        static let watchProgress = "cloud_watch_progress"
        static let continueWatching = "cloud_continue_watching"
    }
    
    static let didSyncFromCloudNotification = Notification.Name("iCloudSyncManager.didSyncFromCloud")
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        
        kvStore.synchronize()
        
        pullFromCloud()
    }
    
    // MARK: - Push (local -> cloud)
    
    func pushWatchProgress(_ progress: [String: Double]) {
        guard !isMergingFromCloud else { return }
        
        if let data = try? encoder.encode(progress) {
            kvStore.set(data, forKey: CloudKeys.watchProgress)
            kvStore.synchronize()
        }
    }
    
    func pushContinueWatching(_ items: [StorageService.ContinueWatchingItem]) {
        guard !isMergingFromCloud else { return }
        
        let cloudItems = items.map { item -> StorageService.ContinueWatchingItem in
            StorageService.ContinueWatchingItem(
                id: item.id,
                contentType: item.contentType,
                title: item.title,
                progress: item.progress,
                currentTime: item.currentTime,
                duration: item.duration,
                timestamp: item.timestamp,
                showId: item.showId,
                episodeId: item.episodeId,
                seasonNumber: item.seasonNumber,
                episodeNumber: item.episodeNumber,
                episodeTitle: item.episodeTitle,
                posterURL: item.posterURL,
                showTitle: item.showTitle,
                snapshotURL: nil,
                streamURL: item.streamURL
            )
        }
        
        if let data = try? encoder.encode(cloudItems) {
            kvStore.set(data, forKey: CloudKeys.continueWatching)
            kvStore.synchronize()
        }
    }
    
    // MARK: - Pull (cloud -> local)
    
    @objc private func handleRemoteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            pullFromCloud()
            return
        }
        
        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            pullFromCloud()
        case NSUbiquitousKeyValueStoreAccountChange:
            pullFromCloud()
        default:
            break
        }
    }
    
    private func pullFromCloud() {
        let cloudProgress = decodeCloudProgress()
        let cloudItems = decodeCloudContinueWatching()
        
        guard !cloudProgress.isEmpty || !cloudItems.isEmpty else { return }
        
        isMergingFromCloud = true
        
        Task { @MainActor in
            let storage = StorageService.shared
            storage.mergeFromCloud(
                watchProgress: cloudProgress,
                continueWatching: cloudItems
            )
            
            isMergingFromCloud = false
            
            NotificationCenter.default.post(
                name: Self.didSyncFromCloudNotification,
                object: nil
            )
        }
    }
    
    // MARK: - Decode helpers
    
    private func decodeCloudProgress() -> [String: Double] {
        guard let data = kvStore.data(forKey: CloudKeys.watchProgress),
              let progress = try? decoder.decode([String: Double].self, from: data) else {
            return [:]
        }
        return progress
    }
    
    private func decodeCloudContinueWatching() -> [StorageService.ContinueWatchingItem] {
        guard let data = kvStore.data(forKey: CloudKeys.continueWatching),
              let items = try? decoder.decode([StorageService.ContinueWatchingItem].self, from: data) else {
            return []
        }
        return items
    }
}
