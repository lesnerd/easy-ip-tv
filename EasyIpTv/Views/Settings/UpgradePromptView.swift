import SwiftUI

/// Paywall view shown when a free-tier limit is hit or from Settings
struct UpgradePromptView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss
    
    /// Optional context message explaining why the prompt was shown
    var reason: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.yellow)
                    
                    Text("Easy IPTV Premium")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let reason = reason {
                        Text(reason)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                    }
                }
                .padding(.top, 20)
                
                // Benefits list
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "xmark.circle", color: .green, text: "No ads — ever")
                    BenefitRow(icon: "list.bullet.rectangle", color: .blue, text: "Unlimited playlists")
                    BenefitRow(icon: "heart.fill", color: .red, text: "Unlimited favorites")
                    BenefitRow(icon: "slider.horizontal.3", color: .purple, text: "HD & custom stream quality")
                    BenefitRow(icon: "captions.bubble", color: .orange, text: "Subtitle support")
                    BenefitRow(icon: "play.circle", color: .cyan, text: "Unlimited Continue Watching")
                    BenefitRow(icon: "clock", color: .mint, text: "Recently Watched history")
                }
                .padding(.horizontal, 24)
                
                // Pricing
                PricingCard(
                    title: "Premium",
                    price: premiumManager.yearlyPriceString,
                    subtitle: "per year",
                    highlight: true
                ) {
                    Task {
                        if let product = premiumManager.yearlyProduct {
                            let success = await premiumManager.purchase(product)
                            if success { dismiss() }
                        } else {
                            premiumManager.purchaseError = "Unable to load subscription. Please check your internet connection and try again."
                            await premiumManager.loadProducts()
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Error message
                if let error = premiumManager.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Loading indicator
                if premiumManager.isLoading {
                    ProgressView()
                        .padding()
                }
                
                // Auto-renewal terms (required by Apple)
                VStack(spacing: 8) {
                    Text("Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your Apple ID account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your Account Settings on the App Store after purchase.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        Link("Terms of Use", destination: URL(string: "https://lesnerd.github.io/easy-ip-tv/terms.html")!)
                            .font(.caption2)
                        Link("Privacy Policy", destination: URL(string: "https://lesnerd.github.io/easy-ip-tv/privacy.html")!)
                            .font(.caption2)
                    }
                }
                .padding(.horizontal, 24)
                
                // Restore purchases
                Button {
                    Task { await premiumManager.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                
                // Close button
                Button {
                    dismiss()
                } label: {
                    Text("Dismiss")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 600)
        #endif
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let title: String
    let price: String
    let subtitle: String
    let highlight: Bool
    var badge: String? = nil
    var onPurchase: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onPurchase()
        } label: {
            VStack(spacing: 12) {
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(price)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(highlight ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(highlight ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: highlight ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #endif
    }
}

// MARK: - Preview

#Preview {
    UpgradePromptView(reason: "You've reached the free tier limit of 10 favorites.")
        .environmentObject(PremiumManager())
}
