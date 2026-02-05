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
                    // Load content at app launch
                    await contentViewModel.loadContentIfNeeded()
                }
        }
    }
}
