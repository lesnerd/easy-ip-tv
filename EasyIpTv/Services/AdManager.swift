import Foundation
import SwiftUI

/// Manages ad display state and play counting for interstitial ads
@MainActor
class AdManager: ObservableObject {
    
    static let shared = AdManager()
    
    @Published var isBannerReady: Bool = true
    @Published var isInterstitialReady: Bool = false
    @Published private(set) var playCount: Int = 0
    
    /// Whether to show real ads (set to true once AdMob SDK is integrated)
    /// For now, uses placeholder banner ads
    static let useRealAds = false
    
    /// AdMob test ad unit IDs (replace with real ones for production)
    static let bannerAdUnitId = "ca-app-pub-3940256099942544/2934735716" // Test banner
    static let interstitialAdUnitId = "ca-app-pub-3940256099942544/4411468910" // Test interstitial
    
    private init() {}
    
    /// Call this each time content is played
    func recordPlay() {
        playCount += 1
    }
    
    /// Resets the play counter
    func resetPlayCount() {
        playCount = 0
    }
    
    /// Attempts to show an interstitial ad
    /// Returns true if an ad was shown (caller should wait before proceeding)
    func showInterstitialIfNeeded(premiumManager: PremiumManager) -> Bool {
        guard premiumManager.shouldShowInterstitial(playCount: playCount) else {
            return false
        }
        
        // TODO: When AdMob SDK is integrated, show real interstitial here
        // For now, this is a placeholder that returns true to indicate
        // the caller should show the InterstitialAdOverlay
        return true
    }
}

// MARK: - Banner Ad View (Placeholder)

/// A banner ad view that shows a subtle upgrade prompt for free users
/// Replace with real AdMob GADBannerView when SDK is integrated
struct BannerAdView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    var onUpgrade: () -> Void = {}
    
    var body: some View {
        if !premiumManager.isPremium {
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
                    
                    Text("From \(premiumManager.monthlyPriceString)/mo")
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
}

// MARK: - Interstitial Ad Overlay (Placeholder)

/// Full-screen overlay shown between content plays for free users
/// Replace with real AdMob interstitial when SDK is integrated
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
                
                // Ad placeholder content
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
                
                // Pricing options
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(premiumManager.monthlyPriceString)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("per month")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(width: 140, height: 80)
                    .background(Color.accentColor.opacity(0.3))
                    .cornerRadius(12)
                    
                    VStack(spacing: 8) {
                        Text(premiumManager.lifetimePriceString)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("lifetime")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(width: 140, height: 80)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(12)
                }
                
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

/// Small overlay shown on locked features (quality selector, etc.)
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
