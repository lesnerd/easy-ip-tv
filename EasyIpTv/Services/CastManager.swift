import Foundation
import SwiftUI

/// Manages Google Cast (Chromecast) sessions.
/// Activated only on iOS when the GoogleCast SDK is linked.
///
/// To enable Chromecast:
/// 1. Add `google-cast-sdk` CocoaPod or SPM package
/// 2. Set your Cast App ID in `CastManager.initialize(appId:)`
/// 3. Uncomment `#if canImport(GoogleCast)` blocks
@MainActor
class CastManager: ObservableObject {
    static let shared = CastManager()
    
    @Published var isCasting: Bool = false
    @Published var castDeviceName: String?
    @Published var isConnecting: Bool = false
    
    private init() {}
    
    /// Call from AppDelegate or App init
    func initialize(appId: String = "CC1AD845") {
        #if os(iOS)
        // When GoogleCast SDK is available:
        // let criteria = GCKDiscoveryCriteria(applicationID: appId)
        // let options = GCKCastOptions(discoveryCriteria: criteria)
        // GCKCastContext.setSharedInstanceWith(options)
        // GCKCastContext.sharedInstance().sessionManager.add(self)
        NSLog("[Cast] Chromecast manager initialized (SDK not yet linked)")
        #endif
    }
    
    func castMedia(url: URL, title: String, subtitle: String? = nil, imageURL: URL? = nil) {
        #if os(iOS)
        guard isCasting else {
            NSLog("[Cast] Not currently connected to a Cast device")
            return
        }
        // When GoogleCast SDK is available:
        // let metadata = GCKMediaMetadata(metadataType: .movie)
        // metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        // if let subtitle { metadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle) }
        // if let imageURL { metadata.addImage(GCKImage(url: imageURL, width: 480, height: 270)) }
        //
        // let builder = GCKMediaInformationBuilder(contentURL: url)
        // builder.streamType = .buffered
        // builder.contentType = "video/mp4"
        // builder.metadata = metadata
        //
        // let request = GCKCastContext.sharedInstance().sessionManager.currentCastSession?
        //     .remoteMediaClient?.loadMedia(builder.build())
        // request?.delegate = self
        NSLog("[Cast] Would cast: %@ to %@", title, castDeviceName ?? "unknown")
        #endif
    }
    
    func stopCasting() {
        #if os(iOS)
        // GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
        isCasting = false
        castDeviceName = nil
        NSLog("[Cast] Stopped casting")
        #endif
    }
    
    func pauseCast() {
        #if os(iOS)
        // GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.pause()
        #endif
    }
    
    func resumeCast() {
        #if os(iOS)
        // GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.play()
        #endif
    }
}

// MARK: - Cast Button (placeholder until SDK is linked)

#if os(iOS)
struct CastButton: View {
    @ObservedObject var castManager = CastManager.shared
    
    var body: some View {
        Button {
            if castManager.isCasting {
                castManager.stopCasting()
            } else {
                NSLog("[Cast] Cast button tapped — SDK not yet linked")
            }
        } label: {
            Image(systemName: castManager.isCasting ? "tv.fill" : "tv")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}
#endif
