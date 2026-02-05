import Foundation
import AVFoundation
import SwiftUI

/// ViewModel for managing video playback
@MainActor
class PlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentChannel: Channel?
    @Published var currentMovie: Movie?
    @Published var currentEpisode: Episode?
    
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var showControls: Bool = true
    @Published var showChannelNavigator: Bool = false
    
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var progress: Double = 0
    
    // MARK: - Private Properties
    
    private let streamService = StreamService.shared
    private let storage = StorageService.shared
    private var controlsTimer: Timer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    
    // MARK: - Computed Properties
    
    /// Current playback title
    var currentTitle: String {
        if let channel = currentChannel {
            return channel.name
        } else if let movie = currentMovie {
            return movie.title
        } else if let episode = currentEpisode {
            return episode.title
        }
        return ""
    }
    
    /// Whether this is live content
    var isLiveContent: Bool {
        currentChannel != nil
    }
    
    /// Formatted current time
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    /// Formatted duration
    var formattedDuration: String {
        formatTime(duration)
    }
    
    // MARK: - Public Methods
    
    /// Plays a channel
    func play(channel: Channel) {
        cleanup()
        currentChannel = channel
        currentMovie = nil
        currentEpisode = nil
        
        storage.saveLastWatchedChannel(id: channel.id)
        
        setupPlayer(url: channel.streamURL)
        player?.play()
        startControlsTimer()
    }
    
    /// Plays a movie
    func play(movie: Movie) {
        cleanup()
        currentChannel = nil
        currentMovie = movie
        currentEpisode = nil
        
        setupPlayer(url: movie.streamURL)
        
        // Resume from saved position if available
        let savedProgress = storage.getWatchProgress(for: movie.id)
        if savedProgress > 0 && savedProgress < 0.95 {
            let seekTime = savedProgress * (player?.currentItem?.duration.seconds ?? 0)
            if seekTime > 0 {
                let cmTime = CMTime(seconds: seekTime, preferredTimescale: 600)
                player?.seek(to: cmTime)
            }
        }
        
        player?.play()
        startControlsTimer()
    }
    
    /// Plays an episode
    func play(episode: Episode) {
        cleanup()
        currentChannel = nil
        currentMovie = nil
        currentEpisode = episode
        
        setupPlayer(url: episode.streamURL)
        
        // Resume from saved position if available
        let savedProgress = storage.getWatchProgress(for: episode.id)
        if savedProgress > 0 && savedProgress < 0.95 {
            let seekTime = savedProgress * (player?.currentItem?.duration.seconds ?? 0)
            if seekTime > 0 {
                let cmTime = CMTime(seconds: seekTime, preferredTimescale: 600)
                player?.seek(to: cmTime)
            }
        }
        
        player?.play()
        startControlsTimer()
    }
    
    /// Toggles play/pause
    func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        showControlsTemporarily()
    }
    
    /// Seeks to a specific position (0.0 to 1.0)
    func seek(to position: Double) {
        guard let duration = player?.currentItem?.duration.seconds,
              duration.isFinite && duration > 0 else { return }
        
        let targetTime = position * duration
        let cmTime = CMTime(seconds: targetTime, preferredTimescale: 600)
        player?.seek(to: cmTime)
        showControlsTemporarily()
    }
    
    /// Seeks forward by seconds
    func seekForward(seconds: Double = 10) {
        guard let currentItem = player?.currentItem else { return }
        let currentSeconds = currentItem.currentTime().seconds
        let targetSeconds = min(currentSeconds + seconds, currentItem.duration.seconds)
        let cmTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        player?.seek(to: cmTime)
        showControlsTemporarily()
    }
    
    /// Seeks backward by seconds
    func seekBackward(seconds: Double = 10) {
        guard let currentItem = player?.currentItem else { return }
        let currentSeconds = currentItem.currentTime().seconds
        let targetSeconds = max(currentSeconds - seconds, 0)
        let cmTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        player?.seek(to: cmTime)
        showControlsTemporarily()
    }
    
    /// Shows the channel navigator
    func showNavigator() {
        showChannelNavigator = true
        hideControls()
    }
    
    /// Hides the channel navigator
    func hideNavigator() {
        showChannelNavigator = false
        showControlsTemporarily()
    }
    
    /// Toggles the channel navigator
    func toggleNavigator() {
        if showChannelNavigator {
            hideNavigator()
        } else {
            showNavigator()
        }
    }
    
    /// Shows controls temporarily
    func showControlsTemporarily() {
        showControls = true
        startControlsTimer()
    }
    
    /// Stops playback and cleans up
    func stop() {
        saveProgress()
        cleanup()
        currentChannel = nil
        currentMovie = nil
        currentEpisode = nil
    }
    
    // MARK: - Private Methods
    
    private func setupPlayer(url: URL) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        setupObservers()
    }
    
    private func setupObservers() {
        guard let player = player else { return }
        
        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                if let duration = self?.player?.currentItem?.duration.seconds,
                   duration.isFinite && duration > 0 {
                    self?.duration = duration
                    self?.progress = time.seconds / duration
                }
            }
        }
        
        // Status observer
        statusObserver = player.currentItem?.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.isBuffering = false
                case .failed:
                    self?.isBuffering = false
                default:
                    self?.isBuffering = true
                }
            }
        }
        
        // Rate observer
        rateObserver = player.observe(\.rate) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }
    }
    
    private func cleanup() {
        controlsTimer?.invalidate()
        controlsTimer = nil
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil
        
        player?.pause()
        player = nil
        
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        progress = 0
    }
    
    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideControls()
            }
        }
    }
    
    private func hideControls() {
        showControls = false
    }
    
    private func saveProgress() {
        guard progress > 0 else { return }
        
        if let movie = currentMovie {
            storage.saveWatchProgress(contentId: movie.id, progress: progress)
        } else if let episode = currentEpisode {
            storage.saveWatchProgress(contentId: episode.id, progress: progress)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
