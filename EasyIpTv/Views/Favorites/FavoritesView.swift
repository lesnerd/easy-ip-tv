import SwiftUI

/// Favorites view showing all favorited content grouped by category
struct FavoritesView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var selectedChannel: Channel?
    @State private var selectedMovie: Movie?
    @State private var selectedShow: Show?
    @State private var showChannelPlayer = false
    @State private var showMoviePlayer = false
    @State private var showMovieDetail = false
    @State private var showShowDetail = false
    @State private var selectedEpisode: Episode?
    @State private var selectedSeasonNumber: Int?
    @State private var showEpisodePlayer = false
    @State private var showUpgradeSheet = false
    
    private var continueWatchingItems: [StorageService.ContinueWatchingItem] {
        StorageService.shared.getContinueWatching()
    }
    
    private var recentlyWatchedItems: [StorageService.WatchedItem] {
        StorageService.shared.getRecentlyWatched()
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if !favoritesViewModel.hasFavorites && continueWatchingItems.isEmpty {
                    emptyView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    contentView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(L10n.Navigation.favorites)
            .onAppear {
                favoritesViewModel.loadSavedFavorites()
            }
            .safeAreaInset(edge: .bottom) {
                BannerAdView { showUpgradeSheet = true }
                    .environmentObject(premiumManager)
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptView()
                .environmentObject(premiumManager)
        }
        .platformFullScreen(isPresented: $showChannelPlayer) {
            if let channel = selectedChannel {
                PlayerView(channel: channel)
            }
        }
        .sheet(isPresented: $showMovieDetail) {
            if let movie = selectedMovie {
                MovieDetailView(movie: movie) {
                    showMovieDetail = false
                    showMoviePlayer = true
                } onToggleFavorite: {
                    toggleFavorite(movie: movie)
                }
            }
        }
        .platformFullScreen(isPresented: $showMoviePlayer) {
            if let movie = selectedMovie {
                PlayerView(movie: movie)
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
                    toggleFavorite(show: show)
                }
            }
        }
        .platformFullScreen(isPresented: $showEpisodePlayer) {
            if let episode = selectedEpisode {
                PlayerView(episode: episode, showContext: selectedShow, seasonNumber: selectedSeasonNumber)
            }
        }
    }
    
    // Featured movies for hero banner
    private var featuredMovies: [Movie] {
        Array(contentViewModel.featuredMovies.prefix(5))
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PlatformMetrics.sectionSpacing) {
                // Continue Watching section (highest priority)
                if !continueWatchingItems.isEmpty {
                    ContinueWatchingSection(
                        items: continueWatchingItems,
                        onPlayMovie: { item in
                            if let movie = contentViewModel.movie(withId: item.id) {
                                selectedMovie = movie
                                showMoviePlayer = true
                            }
                        },
                        onPlayEpisode: { item in
                            if let episodeId = item.episodeId {
                                let episode = Episode(
                                    id: episodeId,
                                    episodeNumber: item.episodeNumber ?? 1,
                                    title: item.episodeTitle ?? item.title,
                                    streamURL: URL(string: "placeholder")!,
                                    watchProgress: item.progress
                                )
                                selectedEpisode = episode
                                showEpisodePlayer = true
                            }
                        }
                    )
                }
                
                // Live TV Favorites Section (all channels in one row)
                if !favoritesViewModel.favoriteChannels.isEmpty {
                    FavoritesSectionView(
                        title: L10n.Navigation.liveTV,
                        icon: "tv.fill",
                        iconColor: .blue,
                        count: favoritesViewModel.favoriteChannels.count
                    ) {
                        ForEach(favoritesViewModel.favoriteChannels) { channel in
                            ChannelCard(channel: channel) {
                                playChannel(channel)
                            } onLongPress: {
                                toggleFavorite(channel: channel)
                            }
                            .frame(width: PlatformMetrics.channelCardWidth)
                        }
                    }
                }
                
                // Movies Favorites Section (all movies in one row)
                if !favoritesViewModel.favoriteMovies.isEmpty {
                    FavoritesSectionView(
                        title: L10n.Navigation.movies,
                        icon: "film.fill",
                        iconColor: .purple,
                        count: favoritesViewModel.favoriteMovies.count
                    ) {
                        ForEach(favoritesViewModel.favoriteMovies) { movie in
                            MovieCard(movie: movie) {
                                selectMovie(movie)
                            } onLongPress: {
                                toggleFavorite(movie: movie)
                            }
                            .frame(width: PlatformMetrics.posterCardWidth)
                        }
                    }
                }
                
                // Shows Favorites Section (all shows in one row)
                if !favoritesViewModel.favoriteShows.isEmpty {
                    FavoritesSectionView(
                        title: L10n.Navigation.shows,
                        icon: "play.rectangle.on.rectangle.fill",
                        iconColor: .orange,
                        count: favoritesViewModel.favoriteShows.count
                    ) {
                        ForEach(favoritesViewModel.favoriteShows) { show in
                            ShowCard(show: show) {
                                selectShow(show)
                            } onLongPress: {
                                toggleFavorite(show: show)
                            }
                            .frame(width: PlatformMetrics.posterCardWidth)
                        }
                    }
                }
                
                // Recently Watched section (at the bottom)
                if !recentlyWatchedItems.isEmpty {
                    RecentlyWatchedSection(
                        items: recentlyWatchedItems,
                        movies: contentViewModel.movies,
                        shows: contentViewModel.shows,
                        onSelectMovie: { movie in
                            selectedMovie = movie
                            showMovieDetail = true
                        },
                        onSelectShow: { show in
                            selectedShow = show
                            showShowDetail = true
                        }
                    )
                }
            }
            .padding(.vertical, PlatformMetrics.contentPadding)
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        EmptyStateView(
            icon: "heart.slash",
            title: L10n.Favorites.noFavorites,
            message: L10n.Favorites.noFavoritesDescription
        )
    }
    
    // MARK: - Actions
    
    private func playChannel(_ channel: Channel) {
        selectedChannel = channel
        showChannelPlayer = true
    }
    
    private func selectMovie(_ movie: Movie) {
        selectedMovie = movie
        showMovieDetail = true
    }
    
    private func selectShow(_ show: Show) {
        selectedShow = show
        showShowDetail = true
    }
    
    private func toggleFavorite(channel: Channel) {
        contentViewModel.toggleFavorite(channel: channel)
        favoritesViewModel.toggleFavorite(channel: channel)
    }
    
    private func toggleFavorite(movie: Movie) {
        contentViewModel.toggleFavorite(movie: movie)
        favoritesViewModel.toggleFavorite(movie: movie)
    }
    
    private func toggleFavorite(show: Show) {
        contentViewModel.toggleFavorite(show: show)
        favoritesViewModel.toggleFavorite(show: show)
    }
}

// MARK: - Favorites Section View (reusable for all content types)

struct FavoritesSectionView<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let count: Int
    @ViewBuilder let content: () -> Content
    
    private var sectionHeaderFont: Font {
        #if os(tvOS)
        return .title
        #else
        return .title2
        #endif
    }
    
    private var rowPadding: CGFloat {
        #if os(tvOS)
        return 50
        #else
        return 16
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(sectionHeaderFont)
                    .fontWeight(.bold)
                Text("(\(count))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            #if os(tvOS)
            .padding(.horizontal, 50)
            #else
            .padding(.horizontal)
            #endif
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    content()
                }
                .padding(.horizontal, rowPadding)
            }
            .platformFocusSection()
        }
    }
}

// MARK: - Favorite Item Card

struct FavoriteItemCard: View {
    let item: FavoriteItem
    var onTap: () -> Void = {}
    var onRemove: () -> Void = {}
    
    var body: some View {
        ContentCard(
            title: item.name,
            subtitle: item.category,
            imageURL: item.imageURL,
            isFavorite: true,
            aspectRatio: item.contentType == .liveTV ? 16/9 : 2/3,
            onTap: onTap,
            onLongPress: onRemove
        )
    }
}

// MARK: - Continue Watching Section

struct ContinueWatchingSection: View {
    let items: [StorageService.ContinueWatchingItem]
    var onPlayMovie: (StorageService.ContinueWatchingItem) -> Void = { _ in }
    var onPlayEpisode: (StorageService.ContinueWatchingItem) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CategoryHeader(
                title: L10n.Content.continueWatching,
                icon: "play.circle",
                itemCount: items.count
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(items) { item in
                        ContinueWatchingItemCard(item: item) {
                            if item.contentType == "movie" {
                                onPlayMovie(item)
                            } else {
                                onPlayEpisode(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, PlatformMetrics.contentPadding + 10)
            }
        }
    }
}

// MARK: - Continue Watching Item Card

struct ContinueWatchingItemCard: View {
    let item: StorageService.ContinueWatchingItem
    var onPlay: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    private var cardWidth: CGFloat {
        #if os(tvOS)
        return 300
        #elseif os(macOS)
        return 260
        #else
        return 220
        #endif
    }
    
    var body: some View {
        Button {
            onPlay()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail with progress
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    Image(systemName: item.contentType == "movie" ? "film" : "play.rectangle.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    
                    // Play button
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    // Progress bar
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * item.progress)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .frame(width: cardWidth)
                .cornerRadius(12)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if item.contentType == "show" {
                        HStack(spacing: 4) {
                            if let season = item.seasonNumber, let episode = item.episodeNumber {
                                Text("S\(season) E\(episode)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let episodeTitle = item.episodeTitle {
                                Text("• \(episodeTitle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    // Time remaining
                    let remaining = max(0, item.duration - item.currentTime)
                    if remaining > 60 {
                        Text("\(Int(remaining / 60)) min left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        #endif
    }
}

// MARK: - Recently Watched Section

struct RecentlyWatchedSection: View {
    let items: [StorageService.WatchedItem]
    let movies: [Movie]
    let shows: [Show]
    var onSelectMovie: (Movie) -> Void = { _ in }
    var onSelectShow: (Show) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CategoryHeader(
                title: L10n.Content.recentlyWatched,
                icon: "clock",
                itemCount: items.count
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(items) { item in
                        RecentlyWatchedCard(
                            item: item,
                            movies: movies,
                            shows: shows,
                            onSelectMovie: onSelectMovie,
                            onSelectShow: onSelectShow
                        )
                    }
                }
                .padding(.horizontal, PlatformMetrics.contentPadding + 10)
            }
        }
    }
}

// MARK: - Recently Watched Card

struct RecentlyWatchedCard: View {
    let item: StorageService.WatchedItem
    let movies: [Movie]
    let shows: [Show]
    var onSelectMovie: (Movie) -> Void = { _ in }
    var onSelectShow: (Show) -> Void = { _ in }
    
    @FocusState private var isFocused: Bool
    
    private var cardWidth: CGFloat {
        #if os(tvOS)
        return 150
        #elseif os(macOS)
        return 130
        #else
        return 120
        #endif
    }
    
    var body: some View {
        Button {
            if item.contentType == "movie" {
                if let movie = movies.first(where: { $0.id == item.id }) {
                    onSelectMovie(movie)
                }
            } else {
                if let show = shows.first(where: { $0.id == item.id }) {
                    onSelectShow(show)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack {
                    if let imageURL = item.imageURL {
                        CachedAsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ShimmerPlaceholder()
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        Image(systemName: item.contentType == "movie" ? "film" : "play.rectangle.on.rectangle")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: cardWidth)
                .cornerRadius(12)
                .clipped()
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    if item.contentType == "show" {
                        if let season = item.seasonNumber, let episode = item.episodeNumber {
                            Text("S\(season) E\(episode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Watched date
                    Text(item.watchedDate.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        #endif
    }
}

// MARK: - Preview

#Preview {
    FavoritesView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
