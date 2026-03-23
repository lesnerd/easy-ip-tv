import SwiftUI

@main
struct EasyIpTvApp: App {
    @StateObject private var contentViewModel = ContentViewModel()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var premiumManager = PremiumManager()
    @StateObject private var downloadManager = DownloadManager.shared
    #if os(tvOS)
    @State private var showSplash = true
    #endif
    
    private var sharedEnvironment: some View {
        MainMenuView()
            .environmentObject(contentViewModel)
            .environmentObject(favoritesViewModel)
            .environmentObject(localizationManager)
            .environmentObject(premiumManager)
            .environmentObject(downloadManager)
            .environment(\.layoutDirection, localizationManager.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
            .id("root-\(localizationManager.currentLanguage.rawValue)")
    }
    
    var body: some Scene {
        WindowGroup {
            #if os(tvOS)
            ZStack {
                sharedEnvironment
                    .opacity(showSplash ? 0 : 1)
                
                if showSplash {
                    SplashLoadingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .task {
                AdManager.shared.initialize()
                downloadManager.performCleanup()
                iCloudSyncManager.shared.startObserving()
                
                let deadline = Date().addingTimeInterval(7)
                
                await contentViewModel.loadContentIfNeeded()
                favoritesViewModel.syncFavorites(
                    channels: contentViewModel.allLoadedChannels,
                    movies: contentViewModel.allLoadedMovies,
                    shows: contentViewModel.allLoadedShows
                )
                
                if contentViewModel.isContentReady {
                    dismissSplash()
                } else {
                    while !contentViewModel.isContentReady && Date() < deadline {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                    dismissSplash()
                }
            }
            #else
            sharedEnvironment
                .task {
                    AdManager.shared.initialize()
                    downloadManager.performCleanup()
                    iCloudSyncManager.shared.startObserving()
                    
                    await contentViewModel.loadContentIfNeeded()
                    favoritesViewModel.syncFavorites(
                        channels: contentViewModel.allLoadedChannels,
                        movies: contentViewModel.allLoadedMovies,
                        shows: contentViewModel.allLoadedShows
                    )
                }
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        #endif
    }
    
    #if os(tvOS)
    private func dismissSplash() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showSplash = false
        }
    }
    #endif
}

// MARK: - Splash Loading View

struct SplashLoadingView: View {
    @State private var progress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            LiquidGradientBackground(intensity: 0.35)
                .ignoresSafeArea()
                .opacity(glowOpacity)
            
            VStack(spacing: 32) {
                Spacer()
                
                Image(systemName: "play.tv.fill")
                    #if os(tvOS)
                    .font(.system(size: 80, weight: .thin))
                    #else
                    .font(.system(size: 56, weight: .thin))
                    #endif
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseScale)
                
                VStack(spacing: 8) {
                    Text("Easy IPTV")
                        #if os(tvOS)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        #else
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        #endif
                        .foregroundColor(.white)
                    
                    Text("Loading your content...")
                        #if os(tvOS)
                        .font(.system(size: 18))
                        #else
                        .font(.system(size: 14))
                        #endif
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Progress bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, progress * splashBarWidth))
                        .shadow(color: AppTheme.primary.opacity(0.5), radius: 8)
                }
                #if os(tvOS)
                .frame(width: splashBarWidth, height: 6)
                #else
                .frame(width: splashBarWidth, height: 4)
                #endif
                .cornerRadius(3)
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
                glowOpacity = 0.6
            }
            withAnimation(.easeInOut(duration: 6.5)) {
                progress = 0.95
            }
        }
    }
    
    private var splashBarWidth: CGFloat {
        #if os(tvOS)
        return 300
        #elseif os(macOS)
        return 240
        #else
        return 200
        #endif
    }
}

// MARK: - Platform Helpers

/// Adaptive spacing and sizing for different platforms
enum PlatformMetrics {
    /// Card width for channel cards
    static var channelCardWidth: CGFloat {
        #if os(tvOS)
        return 320
        #elseif os(macOS)
        return 240
        #else
        return 200
        #endif
    }
    
    /// Card width for movie/show poster cards
    static var posterCardWidth: CGFloat {
        #if os(tvOS)
        return 200
        #elseif os(macOS)
        return 160
        #else
        return 140
        #endif
    }
    
    /// Number of columns in a grid
    static var gridColumns: Int {
        #if os(tvOS)
        return 5
        #elseif os(macOS)
        return 5
        #else
        return 3
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
        return 40
        #elseif os(macOS)
        return 16
        #else
        return 12
        #endif
    }
    
    /// Vertical section spacing
    static var sectionSpacing: CGFloat {
        #if os(tvOS)
        return 48
        #elseif os(macOS)
        return 36
        #else
        return 32
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
        return 400
        #else
        return 420
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
    
    /// Card corner radius
    static var cardCornerRadius: CGFloat {
        #if os(tvOS)
        return 16
        #else
        return 12
        #endif
    }
    
    /// Sidebar width for macOS/iPad/tvOS
    static var sidebarWidth: CGFloat {
        #if os(tvOS)
        return 280
        #else
        return 260
        #endif
    }
    
    /// Tab bar height (iOS custom tab)
    static var tabBarHeight: CGFloat { 80 }
    
    /// Tab bar corner radius
    static var tabBarCornerRadius: CGFloat { 24 }
}

// MARK: - Platform View Modifiers

extension View {
    /// Presents content as fullScreenCover on iOS/tvOS, or a full-window overlay on macOS.
    /// macOS uses overlay because .sheet() crashes with VideoPlayer.
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
        .onChange(of: isPresented.wrappedValue) { _, newValue in
            if !newValue {
                DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
            }
        }
        #else
        self.fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
    
    /// Item-based variant: presents when item is non-nil, passes unwrapped item to content.
    /// Uses `isPresented:` internally on iOS/tvOS to avoid SwiftUI dismiss-on-rerender
    /// issues with `fullScreenCover(item:)` when the parent view re-renders rapidly.
    @ViewBuilder
    func platformFullScreen<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        #if os(macOS)
        self.overlay {
            if let value = item.wrappedValue {
                content(value)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onChange(of: item.wrappedValue == nil) { _, isNil in
            if isNil {
                DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
            }
        }
        #else
        self.fullScreenCover(
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            onDismiss: { item.wrappedValue = nil }
        ) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
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
