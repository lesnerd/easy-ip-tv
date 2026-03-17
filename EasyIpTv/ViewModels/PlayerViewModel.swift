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
    
    // Resume playback
    @Published var showResumePrompt: Bool = false
    @Published var savedPosition: Double = 0
    @Published var savedPositionFormatted: String = ""
    
    // Subtitle support
    @Published var availableSubtitles: [SubtitleTrack] = []
    @Published var selectedSubtitle: SubtitleTrack?
    @Published var showSubtitlePicker: Bool = false
    
    // MARK: - Subtitle Track Model
    
    struct SubtitleTrack: Identifiable, Equatable {
        let id: String
        let displayName: String
        let languageCode: String?
        let option: AVMediaSelectionOption?
        
        static let off = SubtitleTrack(id: "off", displayName: L10n.Player.off, languageCode: nil, option: nil)
    }
    
    // MARK: - Private Properties
    
    private let streamService = StreamService.shared
    private let storage = StorageService.shared
    private var controlsTimer: Timer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var pendingResumeProgress: Double?
    private var pendingResumeContentId: String?
    
    // Show context for episode tracking
    private var currentShowId: String?
    private var currentShowTitle: String?
    private var currentShowPosterURL: URL?
    private var currentSeasonNumber: Int?
    
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
        
        // Check for saved progress and show prompt
        let savedProgressValue = storage.getWatchProgress(for: movie.id)
        if savedProgressValue > 0.05 && savedProgressValue < 0.95 {
            // Show resume prompt - we'll calculate actual time after player is ready
            pendingResumeProgress = savedProgressValue
            pendingResumeContentId = movie.id
        } else {
            player?.play()
        }
        
        startControlsTimer()
    }
    
    /// Plays an episode with optional show context
    func play(episode: Episode, showContext: Show? = nil, seasonNumber: Int? = nil) {
        cleanup()
        currentChannel = nil
        currentMovie = nil
        currentEpisode = episode
        
        // Store show context for tracking
        currentShowId = showContext?.id
        currentShowTitle = showContext?.title
        currentShowPosterURL = showContext?.posterURL
        currentSeasonNumber = seasonNumber
        
        setupPlayer(url: episode.streamURL)
        
        // Check for saved progress and show prompt
        let savedProgressValue = storage.getWatchProgress(for: episode.id)
        if savedProgressValue > 0.05 && savedProgressValue < 0.95 {
            // Show resume prompt - we'll calculate actual time after player is ready
            pendingResumeProgress = savedProgressValue
            pendingResumeContentId = episode.id
        } else {
            player?.play()
        }
        
        startControlsTimer()
    }
    
    /// Resumes playback from saved position
    func resumePlayback() {
        showResumePrompt = false
        
        if savedPosition > 0 {
            let cmTime = CMTime(seconds: savedPosition, preferredTimescale: 600)
            player?.seek(to: cmTime) { [weak self] _ in
                self?.player?.play()
            }
        } else {
            player?.play()
        }
        
        pendingResumeProgress = nil
        pendingResumeContentId = nil
    }
    
    /// Starts playback from beginning
    func startFromBeginning() {
        showResumePrompt = false
        
        // Clear saved progress
        if let contentId = pendingResumeContentId {
            storage.saveWatchProgress(contentId: contentId, progress: 0)
        }
        
        player?.seek(to: .zero) { [weak self] _ in
            self?.player?.play()
        }
        
        pendingResumeProgress = nil
        pendingResumeContentId = nil
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
    
    /// Shows the subtitle picker
    func showSubtitles() {
        loadAvailableSubtitles()
        showSubtitlePicker = true
    }
    
    /// Hides the subtitle picker
    func hideSubtitles() {
        showSubtitlePicker = false
    }
    
    /// Selects a subtitle track
    func selectSubtitle(_ track: SubtitleTrack) {
        selectedSubtitle = track
        
        guard let playerItem = player?.currentItem,
              let subtitleGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }
        
        if let option = track.option {
            playerItem.select(option, in: subtitleGroup)
            // Save preference
            streamService.subtitleLanguage = track.languageCode
        } else {
            // Turn off subtitles
            playerItem.select(nil, in: subtitleGroup)
            streamService.subtitleLanguage = nil
        }
        
        hideSubtitles()
    }
    
    /// Loads available subtitle tracks
    private func loadAvailableSubtitles() {
        guard let playerItem = player?.currentItem else {
            availableSubtitles = [.off]
            return
        }
        
        var tracks: [SubtitleTrack] = [.off]
        
        if let subtitleGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            for option in subtitleGroup.options {
                let displayName = option.displayName
                let languageCode = option.extendedLanguageTag ?? option.locale?.identifier
                let track = SubtitleTrack(
                    id: option.displayName,
                    displayName: displayName,
                    languageCode: languageCode,
                    option: option
                )
                tracks.append(track)
            }
        }
        
        availableSubtitles = tracks
    }
    
    /// Auto-selects subtitle based on saved preference
    private func autoSelectSubtitle() {
        guard let playerItem = player?.currentItem,
              let subtitleGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }
        
        // Check for saved subtitle preference
        if let preferredLanguage = streamService.subtitleLanguage {
            // Find matching subtitle track
            for option in subtitleGroup.options {
                let languageCode = option.extendedLanguageTag ?? option.locale?.identifier
                if languageCode == preferredLanguage {
                    playerItem.select(option, in: subtitleGroup)
                    selectedSubtitle = SubtitleTrack(
                        id: option.displayName,
                        displayName: option.displayName,
                        languageCode: languageCode,
                        option: option
                    )
                    return
                }
            }
            
            // Try matching by app language
            let appLanguage = LocalizationManager.shared.currentLanguage.rawValue
            for option in subtitleGroup.options {
                let languageCode = option.extendedLanguageTag ?? option.locale?.identifier
                if languageCode?.hasPrefix(appLanguage) == true {
                    playerItem.select(option, in: subtitleGroup)
                    selectedSubtitle = SubtitleTrack(
                        id: option.displayName,
                        displayName: option.displayName,
                        languageCode: languageCode,
                        option: option
                    )
                    return
                }
            }
        }
        
        // Default to off
        selectedSubtitle = .off
    }
    
    /// Shows controls temporarily
    func showControlsTemporarily() {
        showControls = true
        startControlsTimer()
    }
    
    /// Stops playback and cleans up completely
    func stop() {
        saveProgress()
        cleanup(destroyPlayer: true)
        currentChannel = nil
        currentMovie = nil
        currentEpisode = nil
    }
    
    // MARK: - Private Methods
    
    private func setupPlayer(url: URL) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Apply quality settings from StreamService
        let quality = streamService.streamQuality
        if quality != .auto {
            playerItem.preferredPeakBitRate = quality.preferredBitRate
        }
        
        if let existingPlayer = player {
            // Reuse existing player - just swap the item (avoids NSView recreation on macOS)
            existingPlayer.replaceCurrentItem(with: playerItem)
        } else {
            // First time - create new player
            player = AVPlayer(playerItem: playerItem)
        }
        
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
                    self?.autoSelectSubtitle()
                    
                    // Check for pending resume prompt
                    if let progress = self?.pendingResumeProgress,
                       let duration = item.duration.seconds.isFinite ? item.duration.seconds : nil,
                       duration > 0 {
                        let resumeTime = progress * duration
                        self?.savedPosition = resumeTime
                        self?.savedPositionFormatted = self?.formatTime(resumeTime) ?? "0:00"
                        self?.showResumePrompt = true
                    }
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
    
    private func cleanup(destroyPlayer: Bool = false) {
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
        
        if destroyPlayer {
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
        
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
            
            let continueItem = StorageService.ContinueWatchingItem(
                id: movie.id,
                contentType: "movie",
                title: movie.title,
                progress: progress,
                currentTime: currentTime,
                duration: duration,
                timestamp: Date(),
                showId: nil,
                episodeId: nil,
                seasonNumber: nil,
                episodeNumber: nil,
                episodeTitle: nil,
                posterURL: movie.posterURL
            )
            storage.saveContinueWatching(item: continueItem)
            
            let recentItem = StorageService.WatchedItem(
                id: movie.id,
                contentType: "movie",
                title: movie.title,
                watchedDate: Date(),
                imageURL: movie.posterURL
            )
            storage.saveRecentlyWatched(item: recentItem)
            
        } else if let episode = currentEpisode {
            storage.saveWatchProgress(contentId: episode.id, progress: progress)
            
            let continueItem = StorageService.ContinueWatchingItem(
                id: episode.id,
                contentType: "show",
                title: currentShowTitle ?? episode.title,
                progress: progress,
                currentTime: currentTime,
                duration: duration,
                timestamp: Date(),
                showId: currentShowId,
                episodeId: episode.id,
                seasonNumber: currentSeasonNumber,
                episodeNumber: episode.episodeNumber,
                episodeTitle: episode.title,
                posterURL: currentShowPosterURL ?? episode.thumbnailURL,
                showTitle: currentShowTitle
            )
            storage.saveContinueWatching(item: continueItem)
            
            // Save to recently watched - save at show level
            let recentItem = StorageService.WatchedItem(
                id: currentShowId ?? episode.id,
                contentType: "show",
                title: currentShowTitle ?? episode.title,
                watchedDate: Date(),
                imageURL: currentShowPosterURL,
                showId: currentShowId,
                seasonNumber: currentSeasonNumber,
                episodeNumber: episode.episodeNumber
            )
            storage.saveRecentlyWatched(item: recentItem)
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
