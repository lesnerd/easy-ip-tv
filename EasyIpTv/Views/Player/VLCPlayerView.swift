import SwiftUI
#if canImport(VLCKitSPM) && !os(macOS)
import VLCKitSPM

/// Controller that exposes VLC player actions to SwiftUI
class VLCPlayerController: ObservableObject {
    fileprivate var mediaPlayer: VLCMediaPlayer?
    
    func togglePlayback() {
        guard let player = mediaPlayer else { return }
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func seekForward(seconds: Int32 = 15) {
        mediaPlayer?.jumpForward(seconds)
    }
    
    func seekBackward(seconds: Int32 = 15) {
        mediaPlayer?.jumpBackward(seconds)
    }
    
    func seek(to fraction: Float) {
        mediaPlayer?.position = fraction
    }
}

/// UIViewRepresentable wrapper around VLCMediaPlayer
struct VLCPlayerUIView: UIViewRepresentable {
    let url: URL
    let controller: VLCPlayerController
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isBuffering: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        DispatchQueue.main.async {
            context.coordinator.setupPlayer(in: view, url: url)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }
    
    class Coordinator: NSObject, VLCMediaPlayerDelegate {
        var parent: VLCPlayerUIView
        var mediaPlayer: VLCMediaPlayer?
        
        init(_ parent: VLCPlayerUIView) {
            self.parent = parent
            super.init()
        }
        
        func setupPlayer(in view: UIView, url: URL) {
            NSLog("[VLC] Setting up player for url=%@", url.absoluteString)
            let player = VLCMediaPlayer()
            player.delegate = self
            player.drawable = view
            
            let media = VLCMedia(url: url)
            media.addOption("--network-caching=3000")
            player.media = media
            player.play()
            
            mediaPlayer = player
            parent.controller.mediaPlayer = player
            parent.isBuffering = true
        }
        
        func stop() {
            mediaPlayer?.stop()
            parent.controller.mediaPlayer = nil
            mediaPlayer = nil
        }
        
        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard let player = mediaPlayer else { return }
            let state = player.state
            let isActuallyPlaying = player.isPlaying
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch state {
                case .playing:
                    self.parent.isPlaying = true
                    self.parent.isBuffering = false
                case .paused:
                    self.parent.isPlaying = false
                    self.parent.isBuffering = false
                case .buffering:
                    self.parent.isBuffering = !isActuallyPlaying
                case .opening:
                    self.parent.isBuffering = true
                case .ended, .stopped, .error:
                    NSLog("[VLC] Playback ended/stopped/error state=%d", state.rawValue)
                    self.parent.isPlaying = false
                    self.parent.isBuffering = false
                @unknown default:
                    break
                }
            }
        }
        
        func mediaPlayerTimeChanged(_ aNotification: Notification) {
            guard let player = mediaPlayer else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let time = Double(player.time.intValue) / 1000.0
                let dur = Double(player.media?.length.intValue ?? 0) / 1000.0
                self.parent.currentTime = time
                if dur > 0 { self.parent.duration = dur }
            }
        }
    }
}
#endif
