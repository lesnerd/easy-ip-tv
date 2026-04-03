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
    @StateObject private var scrubber = ScrubberState()
    @State private var showVLCSubtitlePicker = false
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
        let contentId = movie?.id ?? episode?.id
        if let contentId,
           let localURL = DownloadManager.shared.localURL(for: contentId) {
            return localURL
        }
        let activeChannel = currentLiveChannel ?? channel
        return activeChannel?.streamURL ?? movie?.streamURL ?? episode?.streamURL
    }
    
    /// Determines whether VLC should be used instead of AVPlayer.
    /// VOD always uses VLC. For live TV, we check the URL scheme and path:
    /// AVPlayer handles HLS (.m3u8) well; everything else goes through VLC.
    private var needsVLCPlayer: Bool {
        guard let url = streamURL else { return false }
        if movie != nil || episode != nil { return true }
        let scheme = url.scheme?.lowercased() ?? ""
        let vlcOnlySchemes: Set<String> = ["rtsp", "rtmp", "rtp", "udp", "mms", "mmsh", "rtmps", "rtmpt", "rtmpe"]
        if vlcOnlySchemes.contains(scheme) { return true }
        if scheme == "http" || scheme == "https" {
            let path = url.path.lowercased()
            let query = url.query?.lowercased() ?? ""
            let isHLS = path.hasSuffix(".m3u8") || query.contains(".m3u8")
            return !isHLS
        }
        return true
    }
    
    @State private var vlcPlaybackFailed = false
    @State private var avplayerFallbackAttempted = false
    @State private var currentLiveChannel: Channel?
    @State private var showPlayerEPG = false
    #if os(tvOS)
    @State private var selectedOverlayControl: TVOSControlAction = .tvGuide
    #endif
    
    private var isLiveTV: Bool { channel != nil }
    private var activeChannel: Channel? { currentLiveChannel ?? channel }
    
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
                    isBuffering: $vlcIsBuffering,
                    hasError: $vlcPlaybackFailed
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
            #if os(tvOS)
            // tvOS: Player wrapper -- focusable only when EPG is NOT shown.
            // When EPG opens, this wrapper loses focus, its input handlers stop,
            // and the EPG overlay's buttons receive focus naturally.
            ZStack {
                Group {
                    if useVLCPlayer {
                        #if canImport(VLCKitSPM)
                        VLCPlayerUIView(
                            url: streamURL!,
                            controller: vlcController,
                            isPlaying: $vlcIsPlaying,
                            currentTime: $vlcCurrentTime,
                            duration: $vlcDuration,
                            isBuffering: $vlcIsBuffering,
                            hasError: $vlcPlaybackFailed
                        )
                        #endif
                    } else if let player = playerViewModel.player {
                        TVPlayerLayerView(player: player)
                    }
                }
                .frame(
                    width: showPlayerEPG ? 880 : nil,
                    height: showPlayerEPG ? 440 : nil
                )
                .cornerRadius(showPlayerEPG ? 20 : 0)
                .clipped()
                .overlay {
                    if showPlayerEPG, let ch = activeChannel {
                        tvosVideoInfoOverlay(channel: ch)
                    }
                }
                .shadow(
                    color: showPlayerEPG ? .black.opacity(0.5) : .clear,
                    radius: showPlayerEPG ? 20 : 0
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: showPlayerEPG ? .topLeading : .center
                )
                .padding(.leading, showPlayerEPG ? 60 : 0)
                .padding(.top, showPlayerEPG ? 60 : 0)
                .zIndex(10)
                .animation(.easeInOut(duration: 0.4), value: showPlayerEPG)
                
                if playerViewModel.showControls || (useVLCPlayer && showVLCControls) {
                    if isLiveTV {
                        TVOSLiveOverlay(
                            channel: activeChannel,
                            programTitle: currentEPGProgram,
                            selectedControl: selectedOverlayControl
                        )
                        .allowsHitTesting(false)
                        .zIndex(100)
                    } else {
                        PlayerControlsOverlay(
                            title: useVLCPlayer ? vlcContentTitle : playerViewModel.currentTitle,
                            isPlaying: useVLCPlayer ? vlcIsPlaying : playerViewModel.isPlaying,
                            isLive: false,
                            currentTime: useVLCPlayer ? vlcFormattedTime(vlcCurrentTime) : playerViewModel.formattedCurrentTime,
                            duration: useVLCPlayer ? vlcFormattedTime(vlcDuration) : playerViewModel.formattedDuration,
                            progress: useVLCPlayer ? (vlcDuration > 0 ? vlcCurrentTime / vlcDuration : 0) : playerViewModel.progress,
                            hasSubtitles: useVLCPlayer ? vlcController.subtitleTracks.count > 1 : playerViewModel.availableSubtitles.count > 1,
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
                            onShowSubtitles: {
                                #if canImport(VLCKitSPM)
                                if useVLCPlayer {
                                    vlcController.loadSubtitleTracks()
                                    showVLCSubtitlePicker = true
                                    return
                                }
                                #endif
                                playerViewModel.showSubtitles()
                            },
                            onDismiss: { dismiss() }
                        )
                        .zIndex(100)
                    }
                }
            }
            .focusable(!showPlayerEPG)
            .zIndex(showPlayerEPG ? 50 : 0)
            .onMoveCommand { direction in
                handleRemotePress(direction)
            }
            .onLongPressGesture(minimumDuration: 0.01, pressing: { _ in }) {
                handleRemoteSelect()
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
                    isBuffering: $vlcIsBuffering,
                    hasError: $vlcPlaybackFailed
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
            #endif
            
            // Error overlay when both players have failed
            if vlcPlaybackFailed && (avplayerFallbackAttempted || useVLCPlayer) {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    
                    Text("Unable to Play")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("The format may not be supported or the stream may be offline.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    HStack(spacing: 16) {
                        Button {
                            vlcPlaybackFailed = false
                            avplayerFallbackAttempted = false
                            vlcHasStartedPlaying = false
                            useVLCPlayer = false
                            startPlayback()
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                                .font(.callout.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            dismiss()
                        } label: {
                            Label("Go Back", systemImage: "arrow.left")
                                .font(.callout)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                    .padding(.top, 8)
                }
            }
            // Buffering indicator - for VLC, hide once playback has started (VLC fires many buffering events)
            else if useVLCPlayer ? (vlcIsBuffering && !vlcHasStartedPlaying) : playerViewModel.isBuffering {
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
            if isLiveTV && !showPlayerEPG {
                VStack {
                    Spacer()
                    HStack(spacing: 24) {
                        Button { previousChannel() } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.title2)
                        }
                        Button { playerViewModel.showNavigator() } label: {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPlayerEPG = true
                            }
                        } label: {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(.title2)
                        }
                        Button { nextChannel() } label: {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
                    .shadow(color: AppTheme.primary.opacity(0.20), radius: 15)
                    .padding(.bottom, 20)
                }
            }
            // iOS: VLC controls overlay (VOD and live TV when VLC is active)
            if useVLCPlayer && !isLiveTV && showVLCControls {
                vlcControlsOverlay
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: showVLCControls)
            }
            
            // iOS: Close button — rendered on top of controls overlay so it's always tappable
            if !showPlayerEPG && (useVLCPlayer ? showVLCControls : true) {
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
            #elseif os(tvOS)
            // tvOS controls are inside the player wrapper ZStack above
            #else
            // macOS: full custom controls overlay
            if playerViewModel.showControls || (useVLCPlayer && showVLCControls) {
                PlayerControlsOverlay(
                    title: useVLCPlayer ? vlcContentTitle : playerViewModel.currentTitle,
                    isPlaying: useVLCPlayer ? vlcIsPlaying : playerViewModel.isPlaying,
                    isLive: isLiveTV,
                    currentTime: useVLCPlayer ? vlcFormattedTime(vlcCurrentTime) : playerViewModel.formattedCurrentTime,
                    duration: useVLCPlayer ? vlcFormattedTime(vlcDuration) : playerViewModel.formattedDuration,
                    progress: useVLCPlayer ? (vlcDuration > 0 ? vlcCurrentTime / vlcDuration : 0) : playerViewModel.progress,
                    hasSubtitles: useVLCPlayer ? vlcController.subtitleTracks.count > 1 : playerViewModel.availableSubtitles.count > 1,
                    programTitle: currentEPGProgram,
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
                    onShowEPG: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPlayerEPG = true
                        }
                    },
                    onShowSubtitles: {
                        #if canImport(VLCKitSPM)
                        if useVLCPlayer {
                            vlcController.loadSubtitleTracks()
                            showVLCSubtitlePicker = true
                            return
                        }
                        #endif
                        playerViewModel.showSubtitles()
                    },
                    onDismiss: {
                        dismiss()
                    }
                )
            }
            #endif
            
            // Channel navigator overlay
            if playerViewModel.showChannelNavigator, let currentCh = activeChannel {
                let effectiveChannel = playerViewModel.currentChannel ?? currentCh
                let categoryChannels = contentViewModel.channels(in: effectiveChannel.category)
                ChannelNavigatorOverlay(
                    channels: categoryChannels.isEmpty ? contentViewModel.channels : categoryChannels,
                    currentChannel: effectiveChannel,
                    onSelectChannel: { newChannel in
                        playerViewModel.hideNavigator()
                        playChannel(newChannel)
                    },
                    onDismiss: {
                        playerViewModel.hideNavigator()
                    }
                )
            }
            
            // EPG guide overlay
            if showPlayerEPG, let currentCh = activeChannel {
                let effectiveChannel = playerViewModel.currentChannel ?? currentCh
                let categoryChannels = contentViewModel.channels(in: effectiveChannel.category)
                PlayerEPGOverlay(
                    channels: categoryChannels.isEmpty ? contentViewModel.channels : categoryChannels,
                    currentChannel: effectiveChannel,
                    onSelectChannel: { newChannel in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPlayerEPG = false
                        }
                        playChannel(newChannel)
                    },
                    onPlayCatchup: { channel, program in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPlayerEPG = false
                        }
                        guard let archiveURL = contentViewModel.buildArchiveURL(for: channel, program: program) else { return }
                        let archiveChannel = Channel(
                            id: channel.id,
                            name: "\(channel.name) - \(program.title)",
                            logoURL: channel.logoURL,
                            streamURL: archiveURL,
                            category: channel.category,
                            streamId: channel.streamId
                        )
                        playChannel(archiveChannel)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPlayerEPG = false
                        }
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
            
            // VLC subtitle picker overlay
            #if canImport(VLCKitSPM)
            if showVLCSubtitlePicker {
                VLCSubtitlePickerOverlay(
                    tracks: vlcController.subtitleTracks,
                    selectedIndex: vlcController.currentSubtitleIndex,
                    onSelect: { index in
                        vlcController.selectSubtitle(index: index)
                        showVLCSubtitlePicker = false
                    },
                    onDismiss: {
                        showVLCSubtitlePicker = false
                    }
                )
            }
            #endif
            
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
            if useVLCPlayer { vlcController.togglePlayback() } else { playerViewModel.togglePlayback() }
            #else
            playerViewModel.togglePlayback()
            #endif
        }
        .onExitCommand {
            handleRemoteMenu()
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
            if !isLiveTV {
                #if canImport(VLCKitSPM)
                if useVLCPlayer { vlcController.seekBackward(seconds: 15); return .handled }
                #endif
                playerViewModel.seekBackward()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if !isLiveTV {
                #if canImport(VLCKitSPM)
                if useVLCPlayer { vlcController.seekForward(seconds: 15); return .handled }
                #endif
                playerViewModel.seekForward()
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if isLiveTV && !playerViewModel.showChannelNavigator {
                playerViewModel.showNavigator()
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if playerViewModel.showChannelNavigator {
                playerViewModel.hideNavigator()
            } else if isLiveTV {
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
        .onChange(of: vlcCurrentTime) { _, _ in
            guard vlcDuration > 0 else { return }
            let currentProgress = CGFloat(vlcCurrentTime / vlcDuration)
            scrubber.onPlaybackProgressUpdate(currentProgress: currentProgress, threshold: 0.04)
        }
        .onChange(of: playerViewModel.playbackFailed) { _, failed in
            guard failed, !useVLCPlayer, !avplayerFallbackAttempted else { return }
            NSLog("[PlayerView] AVPlayer failed — falling back to VLC")
            avplayerFallbackAttempted = true
            playerViewModel.stop()
            useVLCPlayer = true
            vlcHasStartedPlaying = false
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
        currentLiveChannel = newChannel
        let url = newChannel.streamURL
        let vlcNeeded = Self.urlNeedsVLC(url)
        
        if vlcNeeded {
            if useVLCPlayer {
                #if canImport(VLCKitSPM)
                vlcController.changeMedia(url: url)
                #endif
            } else {
                playerViewModel.stop()
                useVLCPlayer = true
                vlcHasStartedPlaying = false
                vlcIsBuffering = true
            }
            playerViewModel.currentChannel = newChannel
        } else {
            if useVLCPlayer {
                #if canImport(VLCKitSPM)
                vlcController.stopPlayback()
                #endif
                useVLCPlayer = false
            }
            playerViewModel.play(channel: newChannel)
        }
    }
    
    static func urlNeedsVLC(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        let vlcOnlySchemes: Set<String> = ["rtsp", "rtmp", "rtp", "udp", "mms", "mmsh", "rtmps", "rtmpt", "rtmpe"]
        if vlcOnlySchemes.contains(scheme) { return true }
        if scheme == "http" || scheme == "https" {
            let path = url.path.lowercased()
            let query = url.query?.lowercased() ?? ""
            let isHLS = path.hasSuffix(".m3u8") || query.contains(".m3u8")
            return !isHLS
        }
        return true
    }
    
    private func nextChannel() {
        guard let current = activeChannel,
              let next = contentViewModel.nextChannel(after: current) else { return }
        playChannel(next)
    }
    
    private func previousChannel() {
        guard let current = activeChannel,
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
                snapshotURL: snapshot,
                streamURL: movie.streamURL
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
                snapshotURL: snapshot,
                streamURL: episode.streamURL
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
        
        var progress = StorageService.shared.getWatchProgress(for: contentId)
        
        // Fallback: check ContinueWatchingItem directly (covers auto-queued or
        // desynchronized entries where watchProgress dict has no matching entry)
        if progress <= 0.05 {
            if let item = StorageService.shared.getContinueWatching()
                .first(where: { $0.id == contentId || $0.episodeId == contentId }) {
                progress = item.progress
            }
        }
        
        NSLog("[PlayerView] restoreVLCPosition: progress=%.4f for %@", progress, contentId)
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
        NSLog("[PlayerView] showVLCControlsTemporarily called")
        showVLCControls = true
        vlcControlsTimer?.invalidate()
        vlcControlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation { showVLCControls = false }
            }
        }
    }
    
    private var vlcContentTitle: String {
        activeChannel?.name ?? movie?.title ?? episode?.title ?? "Playing"
    }
    
    private var currentEPGProgram: String? {
        guard let ch = activeChannel else { return nil }
        let key = ch.streamId.map { "\($0)" } ?? ch.epgChannelId ?? ch.tvgId
        guard let key else { return nil }
        return EPGService.shared.nowPlaying(for: key)?.title
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
                    AirPlayButton()
                        .frame(width: 32, height: 32)
                    #if os(iOS)
                    CastButton()
                    #endif
                    #if canImport(VLCKitSPM)
                    if vlcController.subtitleTracks.count > 1 {
                        Button {
                            vlcController.loadSubtitleTracks()
                            showVLCSubtitlePicker = true
                            showVLCControlsTemporarily()
                        } label: {
                            Image(systemName: "captions.bubble")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    #endif
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
                VStack(spacing: 4) {
                    vlcProgressBar
                    
                    HStack {
                        Text(vlcFormattedTime(scrubber.displayProgress(liveProgress: vlcDuration > 0 ? CGFloat(vlcCurrentTime / vlcDuration) : 0) * vlcDuration))
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
                .padding(.bottom, 30)
            }
        }
    }
    
    @ViewBuilder
    private var vlcProgressBar: some View {
        GeometryReader { geo in
            let liveProgress = vlcDuration > 0 ? CGFloat(vlcCurrentTime / vlcDuration) : 0
            let displayProgress = scrubber.displayProgress(liveProgress: liveProgress)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: scrubber.isScrubbing ? 8 : 6)
                
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, geo.size.width * displayProgress), height: scrubber.isScrubbing ? 8 : 6)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: scrubber.isScrubbing ? 28 : 22, height: scrubber.isScrubbing ? 28 : 22)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .offset(x: max(0, geo.size.width * displayProgress - (scrubber.isScrubbing ? 14 : 11)))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = CGFloat(max(0, min(1, value.location.x / geo.size.width)))
                        scrubber.onScrubChanged(fraction: fraction)
                        showVLCControlsTemporarily()
                    }
                    .onEnded { value in
                        let fraction = CGFloat(max(0, min(1, value.location.x / geo.size.width)))
                        scrubber.onScrubEnded(fraction: fraction)
                        #if canImport(VLCKitSPM)
                        vlcController.seek(to: Float(fraction))
                        #endif
                        showVLCControlsTemporarily()
                    }
            )
            .animation(.easeInOut(duration: 0.15), value: scrubber.isScrubbing)
        }
        .frame(height: 44)
    }
    #endif
    
    #if os(tvOS)
    @ViewBuilder
    private func tvosVideoInfoOverlay(channel: Channel) -> some View {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        let program = key.flatMap { EPGService.shared.nowPlaying(for: $0) }
        
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("LIVE NOW")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.green, in: Capsule())
                    
                    Text(channel.category.uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                }
                
                Text(program?.title ?? channel.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPlayerEPG = false
                    }
                } label: {
                    Label("Live", systemImage: "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(AppTheme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.75), Color.black.opacity(0.2), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .background(.ultraThinMaterial.opacity(0.3))
            .environment(\.colorScheme, .dark)
        }
    }
    #endif
    
    #if os(tvOS)
    @State private var tvosControlsTimer: Timer?
    
    private func showTVOSControls() {
        guard !showPlayerEPG else { return }
        playerViewModel.showControls = true
        tvosControlsTimer?.invalidate()
        tvosControlsTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            Task { @MainActor in
                playerViewModel.showControls = false
            }
        }
    }
    
    private func handleOverlayAction(_ action: TVOSControlAction) {
        tvosControlsTimer?.invalidate()
        playerViewModel.showControls = false
        switch action {
        case .channelDown:
            previousChannel()
        case .tvGuide:
            withAnimation(.easeInOut(duration: 0.3)) { showPlayerEPG = true }
        case .channelUp:
            nextChannel()
        }
    }
    
    private func handleRemotePress(_ direction: MoveCommandDirection) {
        guard !showPlayerEPG else { return }
        switch direction {
        case .up, .down:
            if isLiveTV {
                showTVOSControls()
            } else {
                if useVLCPlayer { showVLCControlsTemporarily() } else { playerViewModel.showControlsTemporarily() }
            }
            
        case .left:
            if isLiveTV && playerViewModel.showControls {
                let all = TVOSControlAction.allCases
                if let idx = all.firstIndex(of: selectedOverlayControl), idx > 0 {
                    selectedOverlayControl = all[idx - 1]
                }
                showTVOSControls()
            } else if !isLiveTV {
                #if canImport(VLCKitSPM)
                if useVLCPlayer { vlcController.seekBackward(seconds: 15) } else { playerViewModel.seekBackward() }
                #else
                playerViewModel.seekBackward()
                #endif
                showTVOSControls()
            }
            
        case .right:
            if isLiveTV && playerViewModel.showControls {
                let all = TVOSControlAction.allCases
                if let idx = all.firstIndex(of: selectedOverlayControl), idx < all.count - 1 {
                    selectedOverlayControl = all[idx + 1]
                }
                showTVOSControls()
            } else if !isLiveTV {
                #if canImport(VLCKitSPM)
                if useVLCPlayer { vlcController.seekForward(seconds: 15) } else { playerViewModel.seekForward() }
                #else
                playerViewModel.seekForward()
                #endif
                showTVOSControls()
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleRemoteMenu() {
        if showPlayerEPG {
            withAnimation(.easeInOut(duration: 0.3)) { showPlayerEPG = false }
        } else if playerViewModel.showChannelNavigator {
            playerViewModel.hideNavigator()
        } else if playerViewModel.showControls || showVLCControls {
            playerViewModel.showControls = false
            showVLCControls = false
            tvosControlsTimer?.invalidate()
        } else {
            dismiss()
        }
    }
    
    private func handleRemoteSelect() {
        guard !showPlayerEPG else { return }
        let controlsVisible = playerViewModel.showControls || (useVLCPlayer && showVLCControls)
        if controlsVisible && isLiveTV {
            handleOverlayAction(selectedOverlayControl)
        } else if !controlsVisible {
            if isLiveTV {
                selectedOverlayControl = .tvGuide
                showTVOSControls()
            } else {
                if useVLCPlayer { showVLCControlsTemporarily() } else { playerViewModel.showControlsTemporarily() }
            }
        }
    }
    
    // Legacy — kept for compatibility but primary input is handleRemotePress
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .up, .down:
            break
        case .left:
            if !isLiveTV {
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
            if !isLiveTV {
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
        
        if useVLCPlayer {
            showVLCControlsTemporarily()
        } else {
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
    var programTitle: String? = nil
    
    var onPlayPause: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }
    var onSeekForward: () -> Void = {}
    var onSeekBackward: () -> Void = {}
    var onChannelUp: () -> Void = {}
    var onChannelDown: () -> Void = {}
    var onShowNavigator: () -> Void = {}
    var onShowEPG: () -> Void = {}
    var onShowSubtitles: () -> Void = {}
    var onDismiss: () -> Void = {}
    
    @StateObject private var scrubber = ScrubberState()
    
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
                
                AirPlayButton()
                    .frame(width: 36, height: 36)
                    .padding(.trailing, 12)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.Player.nowPlaying)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let programTitle {
                        Text(programTitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(controlPadding)
            
            Spacer()
            
            // Bottom controls
            VStack(spacing: 20) {
                if !isLive {
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            let displayProgress = scrubber.displayProgress(liveProgress: CGFloat(progress))
                            
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: scrubber.isScrubbing ? 4 : 2.5)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: scrubber.isScrubbing ? 8 : 5)
                                
                                RoundedRectangle(cornerRadius: scrubber.isScrubbing ? 4 : 2.5)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.primaryDim, AppTheme.primary],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, geo.size.width * displayProgress), height: scrubber.isScrubbing ? 8 : 5)
                                    .shadow(color: AppTheme.primary.opacity(0.80), radius: 4)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: scrubber.isScrubbing ? 24 : 18, height: scrubber.isScrubbing ? 24 : 18)
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                                    .offset(x: max(0, geo.size.width * displayProgress - (scrubber.isScrubbing ? 12 : 9)))
                            }
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            #if !os(tvOS)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let fraction = Double(max(0, min(1, value.location.x / geo.size.width)))
                                        scrubber.onScrubChanged(fraction: CGFloat(fraction))
                                    }
                                    .onEnded { value in
                                        let fraction = Double(max(0, min(1, value.location.x / geo.size.width)))
                                        scrubber.onScrubEnded(fraction: CGFloat(fraction))
                                        onSeek(fraction)
                                    }
                            )
                            #endif
                            .animation(.easeInOut(duration: 0.15), value: scrubber.isScrubbing)
                        }
                        .frame(height: 44)
                        .onChange(of: progress) { _, newProgress in
                            scrubber.onPlaybackProgressUpdate(currentProgress: CGFloat(newProgress))
                        }
                        
                        HStack {
                            Text(currentTime)
                                .font(AppTypography.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text(duration)
                                .font(AppTypography.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, controlPadding)
                }
                
                // Control buttons
                HStack(spacing: PlatformMetrics.usesFocusScaling ? 60 : 40) {
                    if isLive {
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
                            onShowEPG()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "list.bullet.rectangle.fill")
                                    .font(.title)
                                Text("TV Guide")
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
            ZStack {
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
                #if os(tvOS)
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 120)
                        .mask(
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                #endif
            }
        )
    }
}

// MARK: - tvOS Live TV Overlay

#if os(tvOS)
enum TVOSControlAction: Int, CaseIterable {
    case channelDown = 0, tvGuide, channelUp
}

struct TVOSLiveOverlay: View {
    let channel: Channel?
    let programTitle: String?
    let selectedControl: TVOSControlAction
    
    var body: some View {
        VStack {
            HStack(spacing: 16) {
                if let ch = channel {
                    CachedAsyncImage(url: ch.logoURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Text(ch.name.prefix(3).uppercased())
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("LIVE")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.red)
                            Text(ch.name)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }
                        if let programTitle {
                            Text(programTitle)
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 80)
            .padding(.top, 50)
            
            Spacer()
            
            HStack(spacing: 40) {
                controlTile(icon: "chevron.down.circle.fill", label: "Ch -", isSelected: selectedControl == .channelDown)
                controlTile(icon: "list.bullet.rectangle.fill", label: "TV Guide", isSelected: selectedControl == .tvGuide)
                controlTile(icon: "chevron.up.circle.fill", label: "Ch +", isSelected: selectedControl == .channelUp)
            }
            .padding(.bottom, 100)
        }
        .background(Color.black.opacity(0.6))
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.85), location: 0),
                    .init(color: Color.black.opacity(0.4), location: 0.35),
                    .init(color: Color.black.opacity(0.4), location: 0.55),
                    .init(color: Color.black.opacity(0.9), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .transition(.opacity)
    }
    
    @ViewBuilder
    private func controlTile(icon: String, label: String, isSelected: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .medium))
            Text(label)
                .font(.system(size: 18, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(width: 170, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(isSelected ? AppTheme.primary.opacity(0.15) : Color.clear)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(isSelected ? AppTheme.primary.opacity(0.7) : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 0.5)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(color: isSelected ? AppTheme.primary.opacity(0.3) : .clear, radius: isSelected ? 12 : 0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
#endif

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
        playerView.controlsStyle = .none
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
#endif

// MARK: - Native tvOS Player View (AVPlayerLayer — no built-in transport controls)

#if os(tvOS)
enum TVRemotePress {
    case up, down, left, right, select, menu, playPause
}

struct TVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> PlayerLayerUIView {
        let view = PlayerLayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
    
    class PlayerLayerUIView: UIView {
        let playerLayer = AVPlayerLayer()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(playerLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
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
