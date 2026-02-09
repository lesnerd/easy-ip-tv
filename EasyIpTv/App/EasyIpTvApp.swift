import SwiftUI

@main
struct EasyIpTvApp: App {
    @StateObject private var contentViewModel = ContentViewModel()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var premiumManager = PremiumManager()
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environmentObject(contentViewModel)
                .environmentObject(favoritesViewModel)
                .environmentObject(localizationManager)
                .environmentObject(premiumManager)
                .environment(\.layoutDirection, localizationManager.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
                // Force full view rebuild when language changes so sidebar flips, titles update, etc.
                .id("root-\(localizationManager.currentLanguage.rawValue)")
                .task {
                    await contentViewModel.loadContentIfNeeded()
                    favoritesViewModel.syncFavorites(
                        channels: contentViewModel.allLoadedChannels,
                        movies: contentViewModel.allLoadedMovies,
                        shows: contentViewModel.allLoadedShows
                    )
                }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        #endif
    }
}

// MARK: - Platform Helpers

/// Adaptive spacing and sizing for different platforms
enum PlatformMetrics {
    /// Card width for channel cards
    static var channelCardWidth: CGFloat {
        #if os(tvOS)
        return 300
        #elseif os(macOS)
        return 220
        #else
        return 180 // iOS/iPadOS
        #endif
    }
    
    /// Card width for movie/show poster cards
    static var posterCardWidth: CGFloat {
        #if os(tvOS)
        return 200
        #elseif os(macOS)
        return 160
        #else
        return 140 // iOS/iPadOS
        #endif
    }
    
    /// Number of columns in a grid
    static var gridColumns: Int {
        #if os(tvOS)
        return 5
        #elseif os(macOS)
        return 5
        #else
        return 3 // iOS/iPadOS - adaptive
        #endif
    }
    
    /// Grid columns for poster content (movies/shows)
    static var posterGridColumns: Int {
        #if os(tvOS)
        return 6
        #elseif os(macOS)
        return 6
        #else
        return 3
        #endif
    }
    
    /// Horizontal spacing between items
    static var horizontalSpacing: CGFloat {
        #if os(tvOS)
        return 50
        #elseif os(macOS)
        return 20
        #else
        return 16
        #endif
    }
    
    /// Vertical section spacing
    static var sectionSpacing: CGFloat {
        #if os(tvOS)
        return 60
        #elseif os(macOS)
        return 32
        #else
        return 28
        #endif
    }
    
    /// Content padding
    static var contentPadding: CGFloat {
        #if os(tvOS)
        return 40
        #elseif os(macOS)
        return 24
        #else
        return 16
        #endif
    }
    
    /// Detail view padding
    static var detailPadding: CGFloat {
        #if os(tvOS)
        return 60
        #elseif os(macOS)
        return 32
        #else
        return 20
        #endif
    }
    
    /// Number of items shown in horizontal row before "See More"
    static var rowItemLimit: Int {
        #if os(tvOS)
        return 10
        #elseif os(macOS)
        return 8
        #else
        return 6
        #endif
    }
    
    /// Number of items shown for movie/show rows
    static var posterRowItemLimit: Int {
        #if os(tvOS)
        return 8
        #elseif os(macOS)
        return 7
        #else
        return 5
        #endif
    }
    
    /// Hero banner height
    static var heroBannerHeight: CGFloat {
        #if os(tvOS)
        return 500
        #elseif os(macOS)
        return 350
        #else
        return 280
        #endif
    }
    
    /// Movie detail poster height
    static var detailPosterHeight: CGFloat {
        #if os(tvOS)
        return 500
        #elseif os(macOS)
        return 360
        #else
        return 300
        #endif
    }
    
    /// Show detail poster height
    static var showDetailPosterHeight: CGFloat {
        #if os(tvOS)
        return 400
        #elseif os(macOS)
        return 300
        #else
        return 240
        #endif
    }
    
    /// Whether focus-based scaling is the primary interaction model
    static var usesFocusScaling: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Platform View Modifiers

extension View {
    /// Presents content as fullScreenCover on iOS/tvOS, or a full-window overlay on macOS
    /// (macOS .sheet() crashes with VideoPlayer due to _AVKit_SwiftUI metadata bug)
    @ViewBuilder
    func platformFullScreen<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(macOS)
        self.overlay {
            if isPresented.wrappedValue {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        #else
        self.fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
    
    /// Applies focus section only on tvOS
    @ViewBuilder
    func platformFocusSection() -> some View {
        #if os(tvOS)
        self.focusSection()
        #else
        self
        #endif
    }
}
