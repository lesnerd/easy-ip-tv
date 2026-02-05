import SwiftUI
import AVKit

/// Full-screen video player view
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var contentViewModel: ContentViewModel
    
    @StateObject private var playerViewModel = PlayerViewModel()
    
    // Content to play
    let channel: Channel?
    let movie: Movie?
    let episode: Episode?
    
    init(channel: Channel) {
        self.channel = channel
        self.movie = nil
        self.episode = nil
    }
    
    init(movie: Movie) {
        self.channel = nil
        self.movie = movie
        self.episode = nil
    }
    
    init(episode: Episode) {
        self.channel = nil
        self.movie = nil
        self.episode = episode
    }
    
    var body: some View {
        ZStack {
            // Video Player
            if let player = playerViewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }
            
            // Buffering indicator
            if playerViewModel.isBuffering {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(2)
                    Text(L10n.Player.buffering)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            // Controls overlay
            if playerViewModel.showControls {
                PlayerControlsOverlay(
                    title: playerViewModel.currentTitle,
                    isPlaying: playerViewModel.isPlaying,
                    isLive: playerViewModel.isLiveContent,
                    currentTime: playerViewModel.formattedCurrentTime,
                    duration: playerViewModel.formattedDuration,
                    progress: playerViewModel.progress,
                    onPlayPause: {
                        playerViewModel.togglePlayback()
                    },
                    onSeek: { position in
                        playerViewModel.seek(to: position)
                    },
                    onSeekForward: {
                        playerViewModel.seekForward()
                    },
                    onSeekBackward: {
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
                    onDismiss: {
                        playerViewModel.stop()
                        dismiss()
                    }
                )
            }
            
            // Channel navigator overlay
            if playerViewModel.showChannelNavigator, channel != nil {
                ChannelNavigatorOverlay(
                    channels: contentViewModel.channels,
                    currentChannel: channel!,
                    onSelectChannel: { newChannel in
                        playerViewModel.hideNavigator()
                        playChannel(newChannel)
                    },
                    onDismiss: {
                        playerViewModel.hideNavigator()
                    }
                )
            }
        }
        .onAppear {
            startPlayback()
        }
        .onDisappear {
            playerViewModel.stop()
        }
        .onPlayPauseCommand {
            playerViewModel.togglePlayback()
        }
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        .onExitCommand {
            if playerViewModel.showChannelNavigator {
                playerViewModel.hideNavigator()
            } else if playerViewModel.showControls {
                playerViewModel.stop()
                dismiss()
            } else {
                playerViewModel.showControlsTemporarily()
            }
        }
    }
    
    // MARK: - Playback Control
    
    private func startPlayback() {
        if let channel = channel {
            playerViewModel.play(channel: channel)
        } else if let movie = movie {
            playerViewModel.play(movie: movie)
        } else if let episode = episode {
            playerViewModel.play(episode: episode)
        }
    }
    
    private func playChannel(_ newChannel: Channel) {
        playerViewModel.play(channel: newChannel)
    }
    
    private func nextChannel() {
        guard let current = channel,
              let next = contentViewModel.nextChannel(after: current) else { return }
        playChannel(next)
    }
    
    private func previousChannel() {
        guard let current = channel,
              let previous = contentViewModel.previousChannel(before: current) else { return }
        playChannel(previous)
    }
    
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
                playerViewModel.seekBackward()
            }
        case .right:
            if !playerViewModel.isLiveContent {
                playerViewModel.seekForward()
            }
        @unknown default:
            break
        }
        
        if !playerViewModel.showChannelNavigator {
            playerViewModel.showControlsTemporarily()
        }
    }
}

// MARK: - Player Controls Overlay

struct PlayerControlsOverlay: View {
    let title: String
    let isPlaying: Bool
    let isLive: Bool
    let currentTime: String
    let duration: String
    let progress: Double
    
    var onPlayPause: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }
    var onSeekForward: () -> Void = {}
    var onSeekBackward: () -> Void = {}
    var onChannelUp: () -> Void = {}
    var onChannelDown: () -> Void = {}
    var onShowNavigator: () -> Void = {}
    var onDismiss: () -> Void = {}
    
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
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.Player.nowPlaying)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .padding(40)
            
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
                    .padding(.horizontal, 40)
                }
                
                // Control buttons
                HStack(spacing: 60) {
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
                                .font(.system(size: 60))
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
                .padding(.bottom, 40)
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

// MARK: - Preview

#Preview {
    PlayerView(channel: Channel(
        name: "Test Channel",
        streamURL: URL(string: "http://test.com/stream.m3u8")!,
        category: "Test"
    ))
    .environmentObject(ContentViewModel())
}
