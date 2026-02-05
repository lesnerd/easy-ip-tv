import Foundation
import AVFoundation

/// Service for managing video stream playback
@MainActor
class StreamService: ObservableObject {
    
    static let shared = StreamService()
    
    // MARK: - Stream Quality
    
    enum StreamQuality: String, CaseIterable {
        case auto = "Auto"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var displayName: String {
            switch self {
            case .auto: return String(localized: "Auto")
            case .high: return String(localized: "High Quality")
            case .medium: return String(localized: "Medium Quality")
            case .low: return String(localized: "Low Quality")
            }
        }
        
        var preferredBitRate: Double {
            switch self {
            case .auto: return 0 // Let AVPlayer decide
            case .high: return 5_000_000 // 5 Mbps
            case .medium: return 2_000_000 // 2 Mbps
            case .low: return 800_000 // 800 Kbps
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var currentPlayer: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var streamQuality: StreamQuality = .auto {
        didSet {
            StorageService.shared.saveStreamQuality(streamQuality.rawValue)
        }
    }
    @Published var subtitleLanguage: String? = nil {
        didSet {
            StorageService.shared.saveSubtitleLanguage(subtitleLanguage)
        }
    }
    
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    
    private init() {
        loadSavedSettings()
    }
    
    private func loadSavedSettings() {
        // Load saved quality
        let savedQuality = StorageService.shared.getStreamQuality()
        streamQuality = StreamQuality(rawValue: savedQuality) ?? .auto
        
        // Load saved subtitle language
        subtitleLanguage = StorageService.shared.getSubtitleLanguage()
    }
    
    // MARK: - Playback Control
    
    /// Creates a player for the given URL
    func prepareStream(url: URL) -> AVPlayer {
        // Clean up existing player
        stopPlayback()
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Apply quality settings
        if streamQuality != .auto {
            playerItem.preferredPeakBitRate = streamQuality.preferredBitRate
        }
        
        let player = AVPlayer(playerItem: playerItem)
        currentPlayer = player
        
        setupObservers(for: player)
        
        return player
    }
    
    /// Starts playback
    func play() {
        currentPlayer?.play()
    }
    
    /// Pauses playback
    func pause() {
        currentPlayer?.pause()
    }
    
    /// Toggles play/pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// Stops playback and cleans up
    func stopPlayback() {
        currentPlayer?.pause()
        removeObservers()
        currentPlayer = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
    }
    
    /// Seeks to a specific time
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        currentPlayer?.seek(to: cmTime)
    }
    
    /// Seeks forward by a number of seconds
    func seekForward(seconds: Double = 10) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    /// Seeks backward by a number of seconds
    func seekBackward(seconds: Double = 10) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    /// Sets the stream quality
    func setQuality(_ quality: StreamQuality) {
        streamQuality = quality
        
        if let playerItem = currentPlayer?.currentItem {
            playerItem.preferredPeakBitRate = quality.preferredBitRate
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers(for player: AVPlayer) {
        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // Status observer
        statusObserver = player.currentItem?.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    self?.isBuffering = false
                case .failed:
                    self?.isBuffering = false
                default:
                    self?.isBuffering = true
                }
            }
        }
        
        // Rate observer (for play/pause state)
        rateObserver = player.observe(\.rate) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }
    }
    
    private func removeObservers() {
        if let observer = timeObserver {
            currentPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil
    }
}
