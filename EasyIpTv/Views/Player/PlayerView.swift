import SwiftUI
import AVKit
#if os(macOS)
import AppKit
#endif

/// Full-screen video player view
struct PlayerView: View {
    @Environment(\.dismiss) private var envDismiss
    @EnvironmentObject var contentViewModel: ContentViewModel
    
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var useVLCPlayer = false
    @State private var vlcIsPlaying = false
    @State private var vlcCurrentTime: Double = 0
    @State private var vlcDuration: Double = 0
    @State private var vlcIsBuffering = false
    @State private var vlcHasStartedPlaying = false
    @State private var showVLCControls = false
    @State private var vlcControlsTimer: Timer?
    @State private var hasRestoredVLCPosition = false
    #if canImport(VLCKitSPM)
    @StateObject private var vlcController = VLCPlayerController()
    #endif
    
    // Content to play
    let channel: Channel?
    let movie: Movie?
    let episode: Episode?
    
    // Show context for episode tracking
    let showContext: Show?
    let seasonNumber: Int?
    
    /// Explicit close action provided by the parent (needed for macOS overlay dismissal)
    private var onClose: (() -> Void)?
    
    init(channel: Channel, onClose: (() -> Void)? = nil) {
        self.channel = channel
        self.movie = nil
        self.episode = nil
        self.showContext = nil
        self.seasonNumber = nil
        self.onClose = onClose
    }
    
    init(movie: Movie, onClose: (() -> Void)? = nil) {
        self.channel = nil
        self.movie = movie
        self.episode = nil
        self.showContext = nil
        self.seasonNumber = nil
        self.onClose = onClose
    }
    
    init(episode: Episode, showContext: Show? = nil, seasonNumber: Int? = nil, onClose: (() -> Void)? = nil) {
        self.channel = nil
        self.movie = nil
        self.episode = episode
        self.showContext = showContext
        self.seasonNumber = seasonNumber
        self.onClose = onClose
    }
    
    private func dismiss() {
        if let onClose {
            onClose()
        } else {
            envDismiss()
        }
    }
    
    private var streamURL: URL? {
        channel?.streamURL ?? movie?.streamURL ?? episode?.streamURL
    }
    
    /// Use VLC for all VOD content (movies/shows) since AVPlayer struggles with many Xtream Codes streams.
    /// Live TV channels still use AVPlayer (they typically serve HLS/TS which AVPlayer handles well).
    private var needsVLCPlayer: Bool {
        guard streamURL != nil else { return false }
        return movie != nil || episode != nil
    }
    
    @State private var bufferingTooLong = false
    @State private var bufferingTimer: Timer?
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background always black
            Color.black.ignoresSafeArea()
            
            // Video Player
            #if os(macOS)
            if useVLCPlayer {
                #if canImport(VLCKitSPM)
                VLCPlayerNSView(
                    url: streamURL!,
                    controller: vlcController,
                    isPlaying: $vlcIsPlaying,
                    currentTime: $vlcCurrentTime,
                    duration: $vlcDuration,
                    isBuffering: $vlcIsBuffering
                )
                .ignoresSafeArea()
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showVLCControlsTemporarily()
                    }
                #endif
            } else {
                NativePlayerView(player: playerViewModel.player)
                    .ignoresSafeArea()
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playerViewModel.showControlsTemporarily()
                    }
            }
            #else
            if useVLCPlayer {
                #if canImport(VLCKitSPM)
                VLCPlayerUIView(
                    url: streamURL!,
                    controller: vlcController,
                    isPlaying: $vlcIsPlaying,
                    currentTime: $vlcCurrentTime,
                    duration: $vlcDuration,
                    isBuffering: $vlcIsBuffering
                )
                .ignoresSafeArea()
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        showVLCControlsTemporarily()
                    }
                #endif
            } else if let player = playerViewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            #endif
            
            // Buffering indicator - for VLC, hide once playback has started (VLC fires many buffering events)
            if useVLCPlayer ? (vlcIsBuffering && !vlcHasStartedPlaying) : playerViewModel.isBuffering {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.white)
                    Text(L10n.Player.buffering)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if bufferingTooLong {
                        Button {
                            dismiss()
                        } label: {
                            Label("Go Back", systemImage: "arrow.left")
                                .font(.callout)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .padding(.top, 8)
                    }
                }
            }
            
            // Controls overlay
            #if os(iOS)
            // iOS: compact channel bar for live TV (native VideoPlayer handles play/pause/seek)
            if playerViewModel.isLiveContent && channel != nil {
                VStack {
                    Spacer()
                    HStack(spacing: 32) {
                        Button { previousChannel() } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.title2)
                        }
                        Button { playerViewModel.showNavigator() } label: {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                        }
                        Button { nextChannel() } label: {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
                    .padding(.bottom, 16)
                }
            }
            // iOS: VLC VOD controls for movies/shows
            if useVLCPlayer && showVLCControls {
                vlcControlsOverlay
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: showVLCControls)
            }
            
            // iOS: Close button — rendered on top of controls overlay so it's always tappable
            if useVLCPlayer ? showVLCControls : true {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(radius: 4)
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: showVLCControls)
            }
            #else
            // macOS/tvOS: full custom controls overlay
            if playerViewModel.showControls || (useVLCPlayer && showVLCControls) {
                PlayerControlsOverlay(
                    title: useVLCPlayer ? vlcContentTitle : playerViewModel.currentTitle,
                    isPlaying: useVLCPlayer ? vlcIsPlaying : playerViewModel.isPlaying,
                    isLive: playerViewModel.isLiveContent,
                    currentTime: useVLCPlayer ? vlcFormattedTime(vlcCurrentTime) : playerViewModel.formattedCurrentTime,
                    duration: useVLCPlayer ? vlcFormattedTime(vlcDuration) : playerViewModel.formattedDuration,
                    progress: useVLCPlayer ? (vlcDuration > 0 ? vlcCurrentTime / vlcDuration : 0) : playerViewModel.progress,
                    hasSubtitles: useVLCPlayer ? false : playerViewModel.availableSubtitles.count > 1,
                    onPlayPause: {
                        #if canImport(VLCKitSPM)
                        if useVLCPlayer { vlcController.togglePlayback(); return }
                        #endif
                        playerViewModel.togglePlayback()
                    },
                    onSeek: { position in
                        #if canImport(VLCKitSPM)
                        if useVLCPlayer { vlcController.seek(to: Float(position)); return }
                        #endif
                        playerViewModel.seek(to: position)
                    },
                    onSeekForward: {
                        #if canImport(VLCKitSPM)
                        if useVLCPlayer { vlcController.seekForward(seconds: 15); return }
                        #endif
                        playerViewModel.seekForward()
                    },
                    onSeekBackward: {
                        #if canImport(VLCKitSPM)
                        if useVLCPlayer { vlcController.seekBackward(seconds: 15); return }
                        #endif
                        playerViewModel.seekBackward()
                    },
                    onChannelUp: {
                        nextChannel()
                    },
                    onChannelDown: {
                        previousChannel()
                    },
                    onShowNavigator: {
                        playerViewModel.showNavigator()
                    },
                    onShowSubtitles: {
                        playerViewModel.showSubtitles()
                    },
                    onDismiss: {
                        dismiss()
                    }
                )
            }
            #endif
            
            // Channel navigator overlay
            if playerViewModel.showChannelNavigator, (playerViewModel.currentChannel ?? channel) != nil {
                ChannelNavigatorOverlay(
                    channels: contentViewModel.channels,
                    currentChannel: playerViewModel.currentChannel ?? channel!,
                    onSelectChannel: { newChannel in
                        playerViewModel.hideNavigator()
                        playChannel(newChannel)
                    },
                    onDismiss: {
                        playerViewModel.hideNavigator()
                    }
                )
            }
            
            // Subtitle picker overlay
            if playerViewModel.showSubtitlePicker {
                SubtitlePickerOverlay(
                    tracks: playerViewModel.availableSubtitles,
                    selectedTrack: playerViewModel.selectedSubtitle,
                    onSelect: { track in
                        playerViewModel.selectSubtitle(track)
                    },
                    onDismiss: {
                        playerViewModel.hideSubtitles()
                    }
                )
            }
            
            // Resume prompt overlay
            if playerViewModel.showResumePrompt {
                ResumePromptOverlay(
                    formattedTime: playerViewModel.savedPositionFormatted,
                    onResume: {
                        playerViewModel.resumePlayback()
                    },
                    onStartOver: {
                        playerViewModel.startFromBeginning()
                    }
                )
            }
        }
        .onAppear {
            NSLog("[PlayerView] onAppear channel=%@ movie=%@ episode=%@ url=%@ needsVLC=%d", channel?.name ?? "nil", movie?.title ?? "nil", episode?.title ?? "nil", streamURL?.absoluteString ?? "nil", needsVLCPlayer ? 1 : 0)
            startPlayback()
        }
        .onDisappear {
            NSLog("[PlayerView] onDisappear")
            if useVLCPlayer {
                saveVLCProgress()
            }
            playerViewModel.stop()
            vlcControlsTimer?.invalidate()
        }
        #if os(tvOS)
        .onPlayPauseCommand {
            #if canImport(VLCKitSPM)
            if useVLCPlayer {
                vlcController.togglePlayback()
            } else {
                playerViewModel.togglePlayback()
            }
            #else
            playerViewModel.togglePlayback()
            #endif
        }
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        .onExitCommand {
            if playerViewModel.showChannelNavigator {
                playerViewModel.hideNavigator()
            } else if playerViewModel.showControls || showVLCControls {
                dismiss()
            } else if useVLCPlayer {
                showVLCControlsTemporarily()
            } else {
                playerViewModel.showControlsTemporarily()
            }
        }
        #endif
        #if os(macOS)
        .onKeyPress(.space) {
            #if canImport(VLCKitSPM)
            if useVLCPlayer { vlcController.togglePlayback(); return .handled }
            #endif
            playerViewModel.togglePlayback()
            return .handled
        }
        .onKeyPress(.escape) {
            if playerViewModel.showChannelNavigator {
                playerViewModel.hideNavigator()
            } else if playerViewModel.showControls {
                dismiss()
            } else {
                playerViewModel.showControlsTemporarily()
            }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if !playerViewModel.isLiveContent {
                #if canImport(VLCKitSPM)
                if useVLCPlayer { vlcController.seekBackward(seconds: 15); return .handled }
                #endif
                playerViewModel.seekBackward()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if !playerViewModel.isLiveContent {
                #if canImport(VLCKitSPM)
                if useVLCPlayer { vlcController.seekForward(seconds: 15); return .handled }
                #endif
                playerViewModel.seekForward()
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if channel != nil && !playerViewModel.showChannelNavigator {
                playerViewModel.showNavigator()
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if playerViewModel.showChannelNavigator {
                playerViewModel.hideNavigator()
            } else if channel != nil {
                playerViewModel.showNavigator()
            }
            return .handled
        }
        #endif
        #if os(iOS)
        .statusBarHidden(true)
        .interactiveDismissDisabled(true)
        #endif
        .onChange(of: vlcIsPlaying) { _, isPlaying in
            if isPlaying {
                vlcHasStartedPlaying = true
                if !hasRestoredVLCPosition {
                    restoreVLCPosition()
                }
            }
        }
        .onChange(of: playerViewModel.isBuffering) { _, isBuffering in
            bufferingTimer?.invalidate()
            if isBuffering {
                bufferingTooLong = false
                bufferingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
                    Task { @MainActor in
                        bufferingTooLong = true
                    }
                }
            } else {
                bufferingTooLong = false
            }
        }
    }
    
    // MARK: - Playback Control
    
    private func startPlayback() {
        if needsVLCPlayer {
            NSLog("[PlayerView] Using VLC player for url=%@", streamURL?.absoluteString ?? "nil")
            useVLCPlayer = true
            #if !os(macOS)
            showVLCControlsTemporarily()
            #endif
            return
        }
        NSLog("[PlayerView] Using AVPlayer for url=%@", streamURL?.absoluteString ?? "nil")
        if let channel = channel {
            playerViewModel.play(channel: channel)
        } else if let movie = movie {
            playerViewModel.play(movie: movie)
        } else if let episode = episode {
            playerViewModel.play(episode: episode, showContext: showContext, seasonNumber: seasonNumber)
        }
    }
    
    private func playChannel(_ newChannel: Channel) {
        playerViewModel.play(channel: newChannel)
    }
    
    private func nextChannel() {
        guard let current = playerViewModel.currentChannel ?? channel,
              let next = contentViewModel.nextChannel(after: current) else { return }
        playChannel(next)
    }
    
    private func previousChannel() {
        guard let current = playerViewModel.currentChannel ?? channel,
              let previous = contentViewModel.previousChannel(before: current) else { return }
        playChannel(previous)
    }
    
    // MARK: - VLC Progress Saving
    
    private func saveVLCProgress() {
        guard vlcDuration > 0 else { return }
        let progress = vlcCurrentTime / vlcDuration
        guard progress > 0 else { return }
        let storage = StorageService.shared
        
        if let movie = movie {
            #if canImport(VLCKitSPM)
            let snapshot = vlcController.captureSnapshot(contentId: movie.id)
            #else
            let snapshot: URL? = nil
            #endif
            
            storage.saveWatchProgress(contentId: movie.id, progress: progress)
            
            let continueItem = StorageService.ContinueWatchingItem(
                id: movie.id,
                contentType: "movie",
                title: movie.title,
                progress: progress,
                currentTime: vlcCurrentTime,
                duration: vlcDuration,
                timestamp: Date(),
                showId: nil,
                episodeId: nil,
                seasonNumber: nil,
                episodeNumber: nil,
                episodeTitle: nil,
                posterURL: movie.posterURL,
                showTitle: nil,
                snapshotURL: snapshot
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
            NSLog("[PlayerView] Saved VLC movie progress: %.2f for %@", progress, movie.title)
            
        } else if let episode = episode {
            #if canImport(VLCKitSPM)
            let snapshot = vlcController.captureSnapshot(contentId: episode.id)
            #else
            let snapshot: URL? = nil
            #endif
            
            storage.saveWatchProgress(contentId: episode.id, progress: progress)
            
            let nextEp = contentViewModel.findNextEpisode(afterEpisodeId: episode.id, inShowId: showContext?.id)
            
            let continueItem = StorageService.ContinueWatchingItem(
                id: episode.id,
                contentType: "show",
                title: showContext?.title ?? episode.title,
                progress: progress,
                currentTime: vlcCurrentTime,
                duration: vlcDuration,
                timestamp: Date(),
                showId: showContext?.id,
                episodeId: episode.id,
                seasonNumber: seasonNumber,
                episodeNumber: episode.episodeNumber,
                episodeTitle: episode.title,
                posterURL: showContext?.posterURL ?? episode.thumbnailURL,
                showTitle: showContext?.title,
                snapshotURL: snapshot
            )
            storage.saveContinueWatching(item: continueItem, nextEpisode: nextEp)
            
            let recentItem = StorageService.WatchedItem(
                id: showContext?.id ?? episode.id,
                contentType: "show",
                title: showContext?.title ?? episode.title,
                watchedDate: Date(),
                imageURL: showContext?.posterURL,
                showId: showContext?.id,
                seasonNumber: seasonNumber,
                episodeNumber: episode.episodeNumber
            )
            storage.saveRecentlyWatched(item: recentItem)
            NSLog("[PlayerView] Saved VLC episode progress: %.2f for %@ S%d E%d", progress, episode.title, seasonNumber ?? 0, episode.episodeNumber)
        }
    }
    
    // MARK: - VLC Resume
    
    private func restoreVLCPosition() {
        hasRestoredVLCPosition = true
        let contentId = movie?.id ?? episode?.id
        guard let contentId else { return }
        let progress = StorageService.shared.getWatchProgress(for: contentId)
        guard progress > 0.05 && progress < 0.95 else { return }
        #if canImport(VLCKitSPM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            vlcController.seek(to: Float(progress))
            NSLog("[PlayerView] Restored VLC position to %.1f%% for %@", progress * 100, contentId)
        }
        #endif
    }
    
    // MARK: - VLC Controls
    
    private func showVLCControlsTemporarily() {
        showVLCControls = true
        vlcControlsTimer?.invalidate()
        vlcControlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation { showVLCControls = false }
            }
        }
    }
    
    private var vlcContentTitle: String {
        movie?.title ?? episode?.title ?? "Playing"
    }
    
    private func vlcFormattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
    
    #if os(iOS)
    @ViewBuilder
    private var vlcControlsOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showVLCControls = false }
                }
            
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text(vlcContentTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Center playback controls
                HStack(spacing: 48) {
                    Button {
                        #if canImport(VLCKitSPM)
                        vlcController.seekBackward(seconds: 15)
                        #endif
                        showVLCControlsTemporarily()
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        #if canImport(VLCKitSPM)
                        vlcController.togglePlayback()
                        #endif
                        showVLCControlsTemporarily()
                    } label: {
                        Image(systemName: vlcIsPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        #if canImport(VLCKitSPM)
                        vlcController.seekForward(seconds: 15)
                        #endif
                        showVLCControlsTemporarily()
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Bottom progress bar
                VStack(spacing: 8) {
                    vlcProgressBar
                    
                    HStack {
                        Text(vlcFormattedTime(vlcCurrentTime))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                        Spacer()
                        Text(vlcFormattedTime(vlcDuration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    @ViewBuilder
    private var vlcProgressBar: some View {
        GeometryReader { geo in
            let progress = vlcDuration > 0 ? CGFloat(vlcCurrentTime / vlcDuration) : 0
            
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                // Progress fill
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, geo.size.width * progress), height: 4)
                
                // Scrubber handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .offset(x: max(0, geo.size.width * progress - 7))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = Float(max(0, min(1, value.location.x / geo.size.width)))
                        #if canImport(VLCKitSPM)
                        vlcController.seek(to: fraction)
                        #endif
                        showVLCControlsTemporarily()
                    }
            )
        }
        .frame(height: 14)
    }
    #endif
    
    #if os(tvOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            if channel != nil && !playerViewModel.showChannelNavigator {
                playerViewModel.showNavigator()
            }
        case .down:
            if playerViewModel.showChannelNavigator {
                playerViewModel.hideNavigator()
            } else if channel != nil {
                playerViewModel.showNavigator()
            }
        case .left:
            if !playerViewModel.isLiveContent {
                #if canImport(VLCKitSPM)
                if useVLCPlayer {
                    vlcController.seekBackward(seconds: 15)
                } else {
                    playerViewModel.seekBackward()
                }
                #else
                playerViewModel.seekBackward()
                #endif
            }
        case .right:
            if !playerViewModel.isLiveContent {
                #if canImport(VLCKitSPM)
                if useVLCPlayer {
                    vlcController.seekForward(seconds: 15)
                } else {
                    playerViewModel.seekForward()
                }
                #else
                playerViewModel.seekForward()
                #endif
            }
        @unknown default:
            break
        }
        
        if !playerViewModel.showChannelNavigator {
            playerViewModel.showControlsTemporarily()
        }
    }
    #endif
}

// MARK: - Player Controls Overlay

struct PlayerControlsOverlay: View {
    let title: String
    let isPlaying: Bool
    let isLive: Bool
    let currentTime: String
    let duration: String
    let progress: Double
    let hasSubtitles: Bool
    
    var onPlayPause: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }
    var onSeekForward: () -> Void = {}
    var onSeekBackward: () -> Void = {}
    var onChannelUp: () -> Void = {}
    var onChannelDown: () -> Void = {}
    var onShowNavigator: () -> Void = {}
    var onShowSubtitles: () -> Void = {}
    var onDismiss: () -> Void = {}
    
    private var controlPadding: CGFloat {
        PlatformMetrics.usesFocusScaling ? 40 : 20
    }
    
    var body: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Subtitle button (only for VOD with subtitles)
                if !isLive && hasSubtitles {
                    Button {
                        onShowSubtitles()
                    } label: {
                        Image(systemName: "captions.bubble")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.Player.nowPlaying)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .padding(controlPadding)
            
            Spacer()
            
            // Bottom controls
            VStack(spacing: 20) {
                // Progress bar (for VOD content)
                if !isLive {
                    VStack(spacing: 8) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(height: 6)
                        .cornerRadius(3)
                        
                        // Time labels
                        HStack {
                            Text(currentTime)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text(duration)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, controlPadding)
                }
                
                // Control buttons
                HStack(spacing: PlatformMetrics.usesFocusScaling ? 60 : 40) {
                    if isLive {
                        // Channel controls for live TV
                        Button {
                            onChannelDown()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.title)
                                Text(L10n.Player.channelDown)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onShowNavigator()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                    .font(.title)
                                Text("Channels")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onChannelUp()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "chevron.up.circle.fill")
                                    .font(.title)
                                Text(L10n.Player.channelUp)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Seek controls for VOD
                        Button {
                            onSeekBackward()
                        } label: {
                            Image(systemName: "gobackward.10")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onPlayPause()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: PlatformMetrics.usesFocusScaling ? 60 : 44))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onSeekForward()
                        } label: {
                            Image(systemName: "goforward.10")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, controlPadding)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Resume Prompt Overlay

struct ResumePromptOverlay: View {
    let formattedTime: String
    var onResume: () -> Void = {}
    var onStartOver: () -> Void = {}
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text(L10n.Player.resumeFrom(formattedTime))
                    .font(.title2)
                    .foregroundColor(.white)
                
                HStack(spacing: 24) {
                    Button {
                        onResume()
                    } label: {
                        Label(L10n.Player.resume, systemImage: "play.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        onStartOver()
                    } label: {
                        Label(L10n.Player.startOver, systemImage: "arrow.counterclockwise")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(PlatformMetrics.detailPadding)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}

// MARK: - Subtitle Picker Overlay

struct SubtitlePickerOverlay: View {
    let tracks: [PlayerViewModel.SubtitleTrack]
    let selectedTrack: PlayerViewModel.SubtitleTrack?
    var onSelect: (PlayerViewModel.SubtitleTrack) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    
    @FocusState private var focusedTrackId: String?
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(L10n.Player.subtitles)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Divider()
                
                // Track list
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(tracks) { track in
                            Button {
                                onSelect(track)
                            } label: {
                                HStack {
                                    Text(track.displayName)
                                        .font(.callout)
                                    
                                    Spacer()
                                    
                                    if selectedTrack?.id == track.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedTrack?.id == track.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .focused($focusedTrackId, equals: track.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(width: 350)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.trailing, PlatformMetrics.contentPadding)
            .padding(.vertical, PlatformMetrics.detailPadding)
        }
        .transition(.move(edge: .trailing))
        .onAppear {
            focusedTrackId = selectedTrack?.id ?? tracks.first?.id
        }
    }
}

// MARK: - Native macOS Player View (bypasses broken _AVKit_SwiftUI)

#if os(macOS)
struct NativePlayerView: NSViewRepresentable {
    let player: AVPlayer?
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none // Use our custom SwiftUI overlays for controls
        // Don't accept first responder so keyboard events go to SwiftUI
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Always update to handle channel switches (player object changes)
        nsView.player = player
    }
}
#endif

// MARK: - Preview

#Preview {
    PlayerView(channel: Channel(
        name: "Test Channel",
        streamURL: URL(string: "http://test.com/stream.m3u8")!,
        category: "Test"
    ))
    .environmentObject(ContentViewModel())
}
