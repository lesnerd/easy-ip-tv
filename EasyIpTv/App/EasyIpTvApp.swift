import SwiftUI

@main
struct EasyIpTvApp: App {
    @StateObject private var contentViewModel = ContentViewModel()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environmentObject(contentViewModel)
                .environmentObject(favoritesViewModel)
                .environmentObject(localizationManager)
                .environment(\.layoutDirection, localizationManager.currentLanguage == .hebrew ? .rightToLeft : .leftToRight)
                .task {
                    // Favorites are already loaded from storage in FavoritesViewModel.init()
                    // Now load content categories
                    await contentViewModel.loadContentIfNeeded()
                    
                    // Sync favorites with loaded content (handles old favorites with IDs only)
                    favoritesViewModel.syncFavorites(
                        channels: contentViewModel.allLoadedChannels,
                        movies: contentViewModel.allLoadedMovies,
                        shows: contentViewModel.allLoadedShows
                    )
                }
        }
    }
}
