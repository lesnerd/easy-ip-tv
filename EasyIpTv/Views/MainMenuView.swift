import SwiftUI

/// Main navigation view -- Liquid Glass navigation shell
struct MainMenuView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) private var scheme
    
    @State private var selectedTab: Tab = .home
    @State private var showMoreSheet = false
    @State private var showSearch = false
    
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
            case .downloads: return L10n.Navigation.downloads
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
        
        static var primaryTabs: [Tab] {
            [.home, .liveTV, .movies, .shows]
        }
        
        static var moreTabs: [Tab] {
            [.downloads, .settings]
        }
    }
    
    var body: some View {
        #if os(macOS)
        macOSNavigation
        #elseif os(tvOS)
        tvOSNavigation
        #else
        iOSNavigation
        #endif
    }
    
    // MARK: - iOS Custom Tab Bar
    
    #if os(iOS)
    private var isMoreTab: Bool {
        Tab.moreTabs.contains(selectedTab)
    }
    
    private var iOSNavigation: some View {
        ZStack(alignment: .bottom) {
            tabContent(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            bottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showMoreSheet) {
            moreSheet
        }
        .fullScreenCover(isPresented: $showSearch) {
            UniversalSearchView()
                .environmentObject(contentViewModel)
                .environmentObject(favoritesViewModel)
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 10) {
            liquidTabBar
            
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.onSurface(scheme).opacity(0.85))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(AppTheme.tabBarBackground(scheme))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                scheme == .dark
                                    ? Color.white.opacity(0.08)
                                    : Color.black.opacity(0.06),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: Color.black.opacity(scheme == .dark ? 0.4 : 0.12), radius: 12, y: 4)
            )
        }
    }
    
    private var liquidTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.primaryTabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    tabBarItem(tab: tab, isSelected: selectedTab == tab && !isMoreTab)
                }
                .buttonStyle(.plain)
            }
            
            Button {
                showMoreSheet = true
            } label: {
                tabBarItem(
                    icon: "ellipsis.circle.fill",
                    title: L10n.Navigation.more,
                    isSelected: isMoreTab
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(AppTheme.tabBarBackground(scheme))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            scheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.06),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(scheme == .dark ? 0.4 : 0.12), radius: 12, y: 4)
        )
    }
    
    private func tabBarItem(tab: Tab? = nil, icon: String? = nil, title: String? = nil, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon ?? tab?.icon ?? "questionmark")
                .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? AppTheme.activeTabText(scheme) : AppTheme.inactiveTabText(scheme))
            
            Text(title ?? tab?.title ?? "")
                .font(AppTypography.tabLabel)
                .foregroundColor(isSelected ? AppTheme.activeTabText(scheme) : AppTheme.inactiveTabText(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
    
    private var moreSheet: some View {
        NavigationStack {
            List {
                ForEach(Tab.moreTabs) { tab in
                    Button {
                        showMoreSheet = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
            }
            .navigationTitle(L10n.Navigation.more)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showMoreSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    #endif
    
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
    
    // MARK: - tvOS Tab Navigation
    
    #if os(tvOS)
    private var tvOSNavigation: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
    }
    #endif
    
    // MARK: - Tab Content
    
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
    
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: PlatformMetrics.usesFocusScaling ? 80 : 50))
                .foregroundColor(AppTheme.onSurfaceVariant(scheme).opacity(0.5))
            
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppTheme.onSurface(scheme))
            
            Text(message)
                .font(AppTypography.body)
                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryPillButtonStyle())
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
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Universal Search View

struct UniversalSearchView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    @State private var selectedMovie: Movie?
    @State private var selectedShow: Show?
    @State private var playingChannel: Channel?
    @State private var showMovieDetail = false
    @State private var showShowDetail = false
    @State private var showMoviePlayer = false
    @State private var showEpisodePlayer = false
    @State private var selectedEpisode: Episode?
    @State private var selectedSeasonNumber: Int?
    
    private var filteredMovies: [Movie] {
        guard searchText.count >= 2 else { return [] }
        return contentViewModel.allLoadedMovies
            .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .prefix(20)
            .map { $0 }
    }
    
    private var filteredShows: [Show] {
        guard searchText.count >= 2 else { return [] }
        return contentViewModel.allLoadedShows
            .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .prefix(20)
            .map { $0 }
    }
    
    private var filteredChannels: [Channel] {
        guard searchText.count >= 2 else { return [] }
        return contentViewModel.allLoadedChannels
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .prefix(20)
            .map { $0 }
    }
    
    private var hasResults: Bool {
        !filteredMovies.isEmpty || !filteredShows.isEmpty || !filteredChannels.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGradientBackground(intensity: 0.15)
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if searchText.count < 2 {
                        emptyPrompt
                    } else if !hasResults {
                        noResultsView
                    } else {
                        resultsList
                    }
                }
            }
            #if !os(macOS)
            .navigationBarHidden(true)
            #endif
        }
        .sheet(isPresented: $showMovieDetail) {
            if let movie = selectedMovie {
                MovieDetailView(movie: movie) {
                    showMovieDetail = false
                    showMoviePlayer = true
                } onToggleFavorite: {
                    contentViewModel.toggleFavorite(movie: movie)
                    favoritesViewModel.toggleFavorite(movie: movie)
                }
                .environmentObject(contentViewModel)
            }
        }
        .platformFullScreen(isPresented: $showMoviePlayer) {
            if let movie = selectedMovie {
                PlayerView(movie: movie)
                    .id(movie.id)
            }
        }
        .sheet(isPresented: $showShowDetail) {
            if let show = selectedShow {
                ShowDetailView(show: show) { episode, seasonNumber in
                    selectedEpisode = episode
                    selectedSeasonNumber = seasonNumber
                    showShowDetail = false
                    showEpisodePlayer = true
                } onToggleFavorite: {
                    contentViewModel.toggleFavorite(show: show)
                    favoritesViewModel.toggleFavorite(show: show)
                }
                .environmentObject(contentViewModel)
            }
        }
        .platformFullScreen(isPresented: $showEpisodePlayer) {
            if let episode = selectedEpisode {
                PlayerView(episode: episode, showContext: selectedShow, seasonNumber: selectedSeasonNumber)
                    .id(episode.id)
            }
        }
        .platformFullScreen(item: $playingChannel) { channel in
            PlayerView(channel: channel, onClose: { playingChannel = nil })
                .id(channel.id)
                .environmentObject(contentViewModel)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                
                TextField(L10n.Actions.search, text: $searchText)
                    .font(AppTypography.body)
                    .foregroundColor(AppTheme.onSurface(scheme))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(AppTheme.surfaceContainer(scheme).opacity(0.6))
                    )
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.glassBorder(scheme), lineWidth: 0.5)
                    )
            )
            
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppTheme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .onAppear {
            isSearchFocused = true
        }
    }
    
    // MARK: - Empty / No Results
    
    private var emptyPrompt: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppTheme.onSurfaceVariant(scheme).opacity(0.3))
            Text("Search movies, shows & live TV")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
            Spacer()
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppTheme.onSurfaceVariant(scheme).opacity(0.3))
            Text("No results for \"\(searchText)\"")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
            Spacer()
        }
    }
    
    // MARK: - Results
    
    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if !filteredChannels.isEmpty {
                    searchSection(title: L10n.Navigation.liveTV, icon: "tv", count: filteredChannels.count) {
                        ForEach(filteredChannels) { channel in
                            searchRow(
                                title: channel.name,
                                subtitle: channel.category,
                                imageURL: channel.logoURL,
                                badge: "LIVE",
                                badgeColor: AppTheme.liveBadge
                            ) {
                                playingChannel = channel
                            }
                        }
                    }
                }
                
                if !filteredMovies.isEmpty {
                    searchSection(title: L10n.Navigation.movies, icon: "film", count: filteredMovies.count) {
                        ForEach(filteredMovies) { movie in
                            searchRow(
                                title: movie.title,
                                subtitle: [
                                    movie.year.map { String($0) },
                                    movie.genre?.components(separatedBy: ",").first
                                ].compactMap { $0 }.joined(separator: " · "),
                                imageURL: movie.posterURL,
                                rating: movie.rating
                            ) {
                                selectedMovie = movie
                                showMovieDetail = true
                            }
                        }
                    }
                }
                
                if !filteredShows.isEmpty {
                    searchSection(title: L10n.Navigation.shows, icon: "play.rectangle.on.rectangle", count: filteredShows.count) {
                        ForEach(filteredShows) { show in
                            searchRow(
                                title: show.title,
                                subtitle: [
                                    show.year.map { String($0) },
                                    "\(show.totalEpisodes) episodes"
                                ].compactMap { $0 }.joined(separator: " · "),
                                imageURL: show.posterURL,
                                rating: show.rating
                            ) {
                                selectedShow = show
                                showShowDetail = true
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func searchSection<Content: View>(
        title: String, icon: String, count: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppTheme.onSurface(scheme))
                
                Text("\(count)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(AppTheme.surfaceContainerHigh(scheme))
                    )
            }
            .padding(.horizontal, 16)
            
            content()
        }
    }
    
    private func searchRow(
        title: String,
        subtitle: String,
        imageURL: URL?,
        badge: String? = nil,
        badgeColor: Color = .clear,
        rating: Double? = nil,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.surfaceContainerHigh(scheme))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundColor(AppTheme.onSurfaceVariant(scheme).opacity(0.4))
                        }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppTheme.onSurface(scheme))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(badgeColor, in: Capsule())
                        }
                        
                        if let rating, rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                            }
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                        }
                        
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(AppTypography.caption)
                                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme).opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MainMenuView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
        .environmentObject(LocalizationManager.shared)
}
