import Foundation
import SwiftUI
#if canImport(GoogleMobileAds) && os(iOS)
import GoogleMobileAds
#endif

/// Manages ad display state and play counting for interstitial ads
@MainActor
class AdManager: ObservableObject {
    
    static let shared = AdManager()
    
    @Published var isBannerReady: Bool = true
    @Published var isInterstitialReady: Bool = false
    @Published private(set) var playCount: Int = 0
    
    /// AdMob ad unit IDs per platform
    static var bannerAdUnitId: String {
        #if os(iOS)
        return "ca-app-pub-4908202278459911/9679463016"
        #elseif os(macOS)
        return "ca-app-pub-4908202278459911/9328109224"
        #else // tvOS
        return "ca-app-pub-4908202278459911/1800972996"
        #endif
    }
    
    static var interstitialAdUnitId: String {
        #if os(iOS)
        return "ca-app-pub-4908202278459911/2937601905"
        #elseif os(macOS)
        return "ca-app-pub-4908202278459911/3114054662"
        #else // tvOS
        return "ca-app-pub-4908202278459911/4075782540"
        #endif
    }
    
    static var appId: String {
        #if os(iOS)
        return "ca-app-pub-4908202278459911~9068400560"
        #elseif os(macOS)
        return "ca-app-pub-4908202278459911~4434875198"
        #else // tvOS
        return "ca-app-pub-4908202278459911~9862607487"
        #endif
    }
    
    #if canImport(GoogleMobileAds) && os(iOS)
    private var interstitialAd: GADInterstitialAd?
    #endif
    
    private init() {}
    
    /// Initialize the ads SDK (call on app launch)
    func initialize() {
        #if canImport(GoogleMobileAds) && os(iOS)
        GADMobileAds.sharedInstance().start { status in
            #if DEBUG
            print("[AdMob] SDK initialized: \(status.adapterStatusesByClassName)")
            #endif
        }
        Task { await preloadInterstitial() }
        #endif
    }
    
    /// Call this each time content is played
    func recordPlay() {
        playCount += 1
    }
    
    /// Resets the play counter
    func resetPlayCount() {
        playCount = 0
    }
    
    /// Attempts to show an interstitial ad
    /// Returns true if an ad should be shown (caller should show the InterstitialAdOverlay)
    func showInterstitialIfNeeded(premiumManager: PremiumManager) -> Bool {
        guard premiumManager.shouldShowInterstitial(playCount: playCount) else {
            return false
        }
        return true
    }
    
    // MARK: - Real Interstitial Ad (iOS)
    
    /// Preloads an interstitial ad so it's ready to show instantly
    func preloadInterstitial() async {
        #if canImport(GoogleMobileAds) && os(iOS)
        do {
            interstitialAd = try await GADInterstitialAd.load(
                withAdUnitID: Self.interstitialAdUnitId,
                request: GADRequest()
            )
            isInterstitialReady = true
            NSLog("[AdMob] Interstitial ad preloaded")
        } catch {
            isInterstitialReady = false
            NSLog("[AdMob] Failed to load interstitial: %@", error.localizedDescription)
        }
        #endif
    }
    
    /// Shows a real AdMob interstitial ad. Calls completion when dismissed.
    /// Returns true if a real ad was shown. Returns false if no ad available (caller should use fallback).
    @discardableResult
    func showRealInterstitial(completion: @escaping () -> Void) -> Bool {
        #if canImport(GoogleMobileAds) && os(iOS)
        guard let ad = interstitialAd else {
            Task { await preloadInterstitial() }
            return false
        }
        
        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        
        let delegate = InterstitialAdDelegate(onDismiss: { [weak self] in
            completion()
            Task { await self?.preloadInterstitial() }
        })
        ad.fullScreenContentDelegate = delegate
        _retainedDelegate = delegate
        
        ad.present(fromRootViewController: rootVC)
        interstitialAd = nil
        isInterstitialReady = false
        return true
        #else
        return false
        #endif
    }
    
    #if canImport(GoogleMobileAds) && os(iOS)
    private var _retainedDelegate: InterstitialAdDelegate?
    #endif
}

#if canImport(GoogleMobileAds) && os(iOS)
private class InterstitialAdDelegate: NSObject, GADFullScreenContentDelegate {
    let onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            onDismiss()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        NSLog("[AdMob] Interstitial failed to present: %@", error.localizedDescription)
        Task { @MainActor in
            onDismiss()
        }
    }
}
#endif

// MARK: - Banner Ad View

/// Shows real AdMob banner on iOS, placeholder upgrade prompt on macOS/tvOS
struct BannerAdView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    var onUpgrade: () -> Void = {}
    
    var body: some View {
        if !premiumManager.isPremium {
            #if canImport(GoogleMobileAds) && os(iOS)
            AdMobBannerView()
                .frame(height: 50)
                .padding(.horizontal)
                .padding(.bottom, 4)
            #else
            placeholderBanner
            #endif
        }
    }
    
    private var placeholderBanner: some View {
        Button {
            onUpgrade()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Premium")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Ad-free experience, unlimited features")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("From \(PremiumManager().yearlyPriceString)/yr")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

// MARK: - AdMob Banner (iOS only)

#if canImport(GoogleMobileAds) && os(iOS)
struct AdMobBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = AdManager.bannerAdUnitId
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        banner.load(GADRequest())
        return banner
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
#endif

// MARK: - Interstitial Ad Overlay

/// Full-screen overlay shown between content plays for free users
struct InterstitialAdOverlay: View {
    @EnvironmentObject var premiumManager: PremiumManager
    var onDismiss: () -> Void = {}
    var onUpgrade: () -> Void = {}
    
    @State private var countdown: Int = 5
    @State private var canDismiss = false
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Ad content
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(.yellow)
                    
                    Text("Enjoying Easy IPTV?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Upgrade to Premium for an ad-free experience\nwith unlimited playlists, favorites, and more.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                
                // Pricing
                VStack(spacing: 8) {
                    Text(premiumManager.yearlyPriceString)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("per year")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 200, height: 80)
                .background(Color.accentColor.opacity(0.3))
                .cornerRadius(16)
                
                // Upgrade button
                Button {
                    onUpgrade()
                } label: {
                    Label("Upgrade Now", systemImage: "crown.fill")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                // Dismiss / countdown
                if canDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Continue with ads")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Continue in \(countdown)s")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(40)
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startCountdown() {
        countdown = 5
        canDismiss = false
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if countdown > 1 {
                    countdown -= 1
                } else {
                    canDismiss = true
                    timer?.invalidate()
                }
            }
        }
    }
}

// MARK: - Premium Lock Overlay

/// Small overlay shown on locked features
struct PremiumLockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(4)
            .background(Color.orange)
            .clipShape(Circle())
    }
}
