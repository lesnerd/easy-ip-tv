import Foundation
import StoreKit
import SwiftUI

private typealias StoreTransaction = StoreKit.Transaction

/// Subscription type for the app
enum SubscriptionType: String, Codable {
    case free
    case yearly
    case lifetime // Legacy, kept for backward compatibility
}

/// Manages premium subscription state using StoreKit 2
@MainActor
class PremiumManager: ObservableObject {
    
    // MARK: - Product IDs
    
    static let yearlyProductId = "com.easycompany.EasyIpTv.premium.yearly"
    
    static let allProductIds: Set<String> = [yearlyProductId]
    
    // MARK: - Published State
    
    @Published var isPremium: Bool = false
    @Published var subscriptionType: SubscriptionType = .free
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String?
    
    // MARK: - Free Tier Limits
    
    static let freeMaxPlaylists = 1
    static let freeMaxFavorites = 10
    static let freeMaxContinueWatching = 3
    static let freeInterstitialEveryNPlays = 5
    
    // MARK: - Private
    
    private var transactionListener: Task<Void, Error>?
    private let storage = StorageService.shared
    
    // MARK: - Initialization
    
    init() {
        // Load cached state immediately (so UI is correct before StoreKit responds)
        loadCachedState()
        
        // Start listening for transaction updates
        transactionListener = listenForTransactions()
        
        // Verify current entitlements and load products
        Task {
            await verifyEntitlements()
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Products
    
    /// Loads available products from the App Store
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.allProductIds)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("[Premium] Failed to load products: \(error)")
        }
    }
    
    /// Returns the yearly subscription product
    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductId }
    }
    
    // MARK: - Purchase
    
    /// Purchases a product
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePremiumState(from: transaction)
                await transaction.finish()
                isLoading = false
                return true
                
            case .userCancelled:
                isLoading = false
                return false
                
            case .pending:
                purchaseError = "Purchase is pending approval."
                isLoading = false
                return false
                
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    /// Restores previous purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        
        do {
            try await AppStore.sync()
            await verifyEntitlements()
        } catch {
            purchaseError = "Failed to restore purchases. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Entitlement Verification
    
    /// Checks all current entitlements to determine premium status
    private func verifyEntitlements() async {
        var foundPremium = false
        var foundType: SubscriptionType = .free
        
        for await result in StoreTransaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.yearlyProductId {
                    foundPremium = true
                    foundType = .yearly
                }
            }
        }
        
        isPremium = foundPremium
        subscriptionType = foundType
        cacheState()
    }
    
    /// Listens for real-time transaction updates (renewals, revocations, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in StoreTransaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await self.updatePremiumState(from: transaction)
                    await transaction.finish()
                }
            }
        }
    }
    
    /// Updates premium state based on a transaction
    private func updatePremiumState(from transaction: StoreTransaction) async {
        if transaction.revocationDate != nil {
            // Purchase was revoked
            isPremium = false
            subscriptionType = .free
        } else if transaction.productID == Self.yearlyProductId {
            // Check if subscription is still active
            if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                isPremium = true
                subscriptionType = .yearly
            } else {
                isPremium = false
                subscriptionType = .free
            }
        }
        
        cacheState()
    }
    
    /// Verifies a StoreKit verification result
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Cache (for instant UI on launch)
    
    private func loadCachedState() {
        if let typeString = UserDefaults.standard.string(forKey: "premium_subscription_type"),
           let type = SubscriptionType(rawValue: typeString) {
            subscriptionType = type
            isPremium = type != .free
        }
    }
    
    private func cacheState() {
        UserDefaults.standard.set(subscriptionType.rawValue, forKey: "premium_subscription_type")
    }
    
    // MARK: - Debug Toggle
    
    #if DEBUG
    /// Manually toggle premium for testing (debug builds only)
    func debugTogglePremium() {
        if isPremium {
            isPremium = false
            subscriptionType = .free
        } else {
            isPremium = true
            subscriptionType = .lifetime
        }
        cacheState()
    }
    #endif
    
    // MARK: - Feature Gating Helpers
    
    /// Whether the user can add another playlist
    func canAddPlaylist(currentCount: Int) -> Bool {
        isPremium || currentCount < Self.freeMaxPlaylists
    }
    
    /// Whether the user can add another favorite
    func canAddFavorite(currentCount: Int) -> Bool {
        isPremium || currentCount < Self.freeMaxFavorites
    }
    
    /// Whether the user can select stream quality manually
    var canSelectQuality: Bool {
        isPremium
    }
    
    /// Whether the user can use subtitles
    var canUseSubtitles: Bool {
        isPremium
    }
    
    /// Whether recently watched feature is available
    var canUseRecentlyWatched: Bool {
        isPremium
    }
    
    /// Max continue watching items allowed
    var continueWatchingLimit: Int {
        isPremium ? 50 : Self.freeMaxContinueWatching
    }
    
    /// Whether an interstitial ad should be shown based on play count
    func shouldShowInterstitial(playCount: Int) -> Bool {
        !isPremium && playCount > 0 && playCount % Self.freeInterstitialEveryNPlays == 0
    }
    
    // MARK: - Formatted Prices
    
    /// Formatted yearly price string
    var yearlyPriceString: String {
        yearlyProduct?.displayPrice ?? "$11.90"
    }
    
    // MARK: - Errors
    
    enum StoreError: Error, LocalizedError {
        case verificationFailed
        
        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return "Purchase verification failed."
            }
        }
    }
}
