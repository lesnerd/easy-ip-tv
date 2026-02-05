import SwiftUI

/// Main navigation view with tab bar
struct MainMenuView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    
    @State private var selectedTab: Tab = .favorites
    
    enum Tab: String, CaseIterable {
        case favorites
        case liveTV
        case movies
        case shows
        case settings
        
        var title: String {
            switch self {
            case .favorites: return L10n.Navigation.favorites
            case .liveTV: return L10n.Navigation.liveTV
            case .movies: return L10n.Navigation.movies
            case .shows: return L10n.Navigation.shows
            case .settings: return L10n.Navigation.settings
            }
        }
        
        var icon: String {
            switch self {
            case .favorites: return "heart.fill"
            case .liveTV: return "tv"
            case .movies: return "film"
            case .shows: return "play.rectangle.on.rectangle"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FavoritesView()
                .tabItem {
                    Label(Tab.favorites.title, systemImage: Tab.favorites.icon)
                }
                .tag(Tab.favorites)
            
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
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .onChange(of: contentViewModel.channels) { _, channels in
            favoritesViewModel.updateFavorites(
                channels: channels,
                movies: contentViewModel.movies,
                shows: contentViewModel.shows
            )
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
        VStack(spacing: 30) {
            Image(systemName: icon)
                .font(.system(size: 80))
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
