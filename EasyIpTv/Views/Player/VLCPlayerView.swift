import SwiftUI
#if canImport(VLCKitSPM)
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

/// Shared VLC delegate that updates SwiftUI bindings
class VLCCoordinator: NSObject, VLCMediaPlayerDelegate {
    var isPlayingBinding: Binding<Bool>
    var currentTimeBinding: Binding<Double>
    var durationBinding: Binding<Double>
    var isBufferingBinding: Binding<Bool>
    var controller: VLCPlayerController
    var mediaPlayer: VLCMediaPlayer?
    
    init(isPlaying: Binding<Bool>, currentTime: Binding<Double>, duration: Binding<Double>, isBuffering: Binding<Bool>, controller: VLCPlayerController) {
        self.isPlayingBinding = isPlaying
        self.currentTimeBinding = currentTime
        self.durationBinding = duration
        self.isBufferingBinding = isBuffering
        self.controller = controller
        super.init()
    }
    
    #if os(macOS)
    func setupPlayer(in view: NSView, url: URL) {
        NSLog("[VLC-macOS] Setting up player for url=%@", url.absoluteString)
        let player = VLCMediaPlayer()
        player.delegate = self
        player.drawable = view
        
        let media = VLCMedia(url: url)
        media.addOption("--network-caching=3000")
        player.media = media
        player.play()
        
        mediaPlayer = player
        controller.mediaPlayer = player
        isBufferingBinding.wrappedValue = true
    }
    #else
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
        controller.mediaPlayer = player
        isBufferingBinding.wrappedValue = true
    }
    #endif
    
    func stop() {
        mediaPlayer?.stop()
        controller.mediaPlayer = nil
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
                self.isPlayingBinding.wrappedValue = true
                self.isBufferingBinding.wrappedValue = false
            case .paused:
                self.isPlayingBinding.wrappedValue = false
                self.isBufferingBinding.wrappedValue = false
            case .buffering:
                self.isBufferingBinding.wrappedValue = !isActuallyPlaying
            case .opening:
                self.isBufferingBinding.wrappedValue = true
            case .ended, .stopped, .error:
                NSLog("[VLC] Playback ended/stopped/error state=%d", state.rawValue)
                self.isPlayingBinding.wrappedValue = false
                self.isBufferingBinding.wrappedValue = false
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
            self.currentTimeBinding.wrappedValue = time
            if dur > 0 { self.durationBinding.wrappedValue = dur }
        }
    }
}

// MARK: - macOS VLC Player (NSViewRepresentable)

#if os(macOS)
struct VLCPlayerNSView: NSViewRepresentable {
    let url: URL
    let controller: VLCPlayerController
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isBuffering: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        DispatchQueue.main.async {
            context.coordinator.setupPlayer(in: view, url: url)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> VLCCoordinator {
        VLCCoordinator(isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, isBuffering: $isBuffering, controller: controller)
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: VLCCoordinator) {
        coordinator.stop()
    }
}
#endif

// MARK: - iOS/tvOS VLC Player (UIViewRepresentable)

#if !os(macOS)
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
    
    func makeCoordinator() -> VLCCoordinator {
        VLCCoordinator(isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, isBuffering: $isBuffering, controller: controller)
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: VLCCoordinator) {
        coordinator.stop()
    }
}
#endif

#endif // canImport(VLCKitSPM)
