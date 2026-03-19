import SwiftUI

/// Main navigation view - sidebar on macOS, tabs on iOS/tvOS
struct MainMenuView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    
    @State private var selectedTab: Tab = .home
    
    enum Tab: String, CaseIterable, Identifiable {
        case home
        case liveTV
        case movies
        case shows
        case downloads
        case settings
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .home: return L10n.Navigation.home
            case .liveTV: return L10n.Navigation.liveTV
            case .movies: return L10n.Navigation.movies
            case .shows: return L10n.Navigation.shows
            case .downloads: return "Downloads"
            case .settings: return L10n.Navigation.settings
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .liveTV: return "tv"
            case .movies: return "film"
            case .shows: return "play.rectangle.on.rectangle"
            case .downloads: return "arrow.down.circle.fill"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        #if os(macOS)
        macOSNavigation
        #else
        tabNavigation
        #endif
    }
    
    // MARK: - macOS Sidebar Navigation
    
    #if os(macOS)
    private var macOSNavigation: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section {
                    ForEach(Tab.allCases.filter { $0 != .settings }) { tab in
                        Label(tab.title, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                
                Section {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                        .tag(Tab.settings)
                }
            }
            .navigationTitle("Easy IPTV")
            .listStyle(.sidebar)
        } detail: {
            tabContent(for: selectedTab)
        }
    }
    #endif
    
    // MARK: - Tab Navigation (iOS/tvOS)
    
    private var tabNavigation: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)
            
            LiveTVView()
                .tabItem {
                    Label(Tab.liveTV.title, systemImage: Tab.liveTV.icon)
                }
                .tag(Tab.liveTV)
            
            MoviesView()
                .tabItem {
                    Label(Tab.movies.title, systemImage: Tab.movies.icon)
                }
                .tag(Tab.movies)
            
            ShowsView()
                .tabItem {
                    Label(Tab.shows.title, systemImage: Tab.shows.icon)
                }
                .tag(Tab.shows)
            
            DownloadsView()
                .tabItem {
                    Label(Tab.downloads.title, systemImage: Tab.downloads.icon)
                }
                .tag(Tab.downloads)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
    }
    
    // MARK: - Tab Content (for macOS detail view)
    
    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .liveTV:
            LiveTVView()
        case .movies:
            MoviesView()
        case .shows:
            ShowsView()
        case .downloads:
            DownloadsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: PlatformMetrics.usesFocusScaling ? 80 : 50))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = L10n.Player.loading
    var useSkeleton: Bool = true
    
    var body: some View {
        if useSkeleton {
            SkeletonPageView()
        } else {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainMenuView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
        .environmentObject(LocalizationManager.shared)
}
