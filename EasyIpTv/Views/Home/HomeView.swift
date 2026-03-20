import SwiftUI

/// Home screen -- the primary landing tab. Displays Continue Watching, Trending content,
/// and Favorites. Free-tier users are prompted to upgrade on every content interaction.
struct HomeView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var selectedMovie: Movie?
    @State private var selectedShow: Show?
    @State private var playingChannel: Channel?
    @State private var showMoviePlayer = false
    @State private var showMovieDetail = false
    @State private var showShowDetail = false
    @State private var selectedEpisode: Episode?
    @State private var selectedSeasonNumber: Int?
    @State private var showEpisodePlayer = false
    @State private var showUpgradeSheet = false
    @State private var showPremiumUpgrade = false
    @State private var pendingAction: (() -> Void)?
    @State private var continueWatchingItems: [StorageService.ContinueWatchingItem] = []
    #if os(macOS)
    @State private var movieToPlay: Movie?
    @State private var showToPlay: Show?
    #endif
    
    var body: some View {
        NavigationStack {
            Group {
                if contentViewModel.isLoading && contentViewModel.trendingMovies.isEmpty {
                    LoadingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !contentViewModel.hasContent && contentViewModel.trendingMovies.isEmpty && continueWatchingItems.isEmpty && !favoritesViewModel.hasFavorites {
                    EmptyStateView(
                        icon: "tv",
                        title: L10n.Errors.noPlaylist,
                        message: "Add a playlist in Settings to get started."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: PlatformMetrics.sectionSpacing) {
                            // Hero banner
                            if let hero = contentViewModel.trendingMovies.first {
                                heroBanner(movie: hero)
                            }
                            
                            // Continue Watching
                            if !continueWatchingItems.isEmpty {
                                continueWatchingSection
                            }
                            
                            // Trending Movies
                            if !contentViewModel.trendingMovies.isEmpty {
                                trendingMoviesSection
                            }
                            
                            // Trending Series
                            if !contentViewModel.trendingShows.isEmpty {
                                trendingSeriesSection
                            }
                            
                            // Trending Live TV
                            if !contentViewModel.trendingChannels.isEmpty {
                                trendingLiveTVSection
                            }
                            
                            // My Favorites
                            if favoritesViewModel.hasFavorites {
                                favoritesSection
                            }
                        }
                        .padding(.vertical, PlatformMetrics.contentPadding)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if !os(tvOS)
            .navigationTitle(L10n.Navigation.home)
            #endif
            .safeAreaInset(edge: .bottom) {
                #if os(macOS)
                BannerAdView { showPremiumUpgrade = true }
                    .environmentObject(premiumManager)
                #else
                BannerAdView { showUpgradeSheet = true }
                    .environmentObject(premiumManager)
                #endif
            }
        }
        .task {
            favoritesViewModel.loadSavedFavorites()
            while contentViewModel.isLoading || (!contentViewModel.hasContent && contentViewModel.liveCategories.isEmpty && contentViewModel.vodCategories.isEmpty && contentViewModel.seriesCategories.isEmpty) {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !contentViewModel.isLoading && contentViewModel.liveCategories.isEmpty && contentViewModel.vodCategories.isEmpty && contentViewModel.seriesCategories.isEmpty {
                    break
                }
            }
            await contentViewModel.loadTrendingContent()
        }
        .onAppear {
            reloadContinueWatching()
        }
        .onChange(of: showMoviePlayer) { _, isPresented in
            if !isPresented { reloadContinueWatching() }
        }
        .onChange(of: showEpisodePlayer) { _, isPresented in
            if !isPresented { reloadContinueWatching() }
        }
        .onChange(of: playingChannel) { _, value in
            if value == nil { reloadContinueWatching() }
        }
        #if os(macOS)
        .sheet(isPresented: $showPremiumUpgrade) {
            UpgradePromptView()
                .environmentObject(premiumManager)
        }
        #else
        .sheet(isPresented: $showUpgradeSheet, onDismiss: {
            runPendingActionAfterDismiss()
        }) {
            UpgradePromptView()
                .environmentObject(premiumManager)
        }
        #endif
        .platformFullScreen(item: $playingChannel) { channel in
            PlayerView(channel: channel, onClose: { playingChannel = nil })
                .id(channel.id)
                .environmentObject(contentViewModel)
        }
        #if os(macOS)
        .sheet(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie) {
                movieToPlay = movie
                selectedMovie = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showMoviePlayer = true
                }
            } onToggleFavorite: {
                contentViewModel.toggleFavorite(movie: movie)
                favoritesViewModel.toggleFavorite(movie: movie)
            }
            .environmentObject(contentViewModel)
        }
        .platformFullScreen(isPresented: $showMoviePlayer) {
            if let movie = movieToPlay ?? selectedMovie {
                PlayerView(movie: movie, onClose: {
                    showMoviePlayer = false
                    movieToPlay = nil
                })
                .id(movie.id)
            }
        }
        .sheet(item: $selectedShow) { show in
            ShowDetailView(show: show) { episode, seasonNumber in
                selectedEpisode = episode
                selectedSeasonNumber = seasonNumber
                showToPlay = show
                selectedShow = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showEpisodePlayer = true
                }
            } onToggleFavorite: {
                contentViewModel.toggleFavorite(show: show)
                favoritesViewModel.toggleFavorite(show: show)
            }
        }
        .platformFullScreen(isPresented: $showEpisodePlayer) {
            if let episode = selectedEpisode {
                PlayerView(episode: episode, showContext: showToPlay ?? selectedShow, seasonNumber: selectedSeasonNumber, onClose: {
                    showEpisodePlayer = false
                    showToPlay = nil
                })
                .id(episode.id)
            }
        }
        #else
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
            }
        }
        .platformFullScreen(isPresented: $showEpisodePlayer) {
            if let episode = selectedEpisode {
                PlayerView(episode: episode, showContext: selectedShow, seasonNumber: selectedSeasonNumber)
                    .id(episode.id)
            }
        }
        #endif
    }
    
    // MARK: - Gate for free-tier users
    
    private func gatedAction(_ action: @escaping () -> Void) {
        #if os(macOS)
        // On macOS, let users browse freely — interstitial ads show on play
        // (handled by MovieDetailView / ShowDetailView), avoiding the
        // overlay-then-sheet timing bug unique to macOS SwiftUI.
        action()
        #else
        if premiumManager.isPremium {
            action()
        } else {
            pendingAction = action
            showUpgradeSheet = true
        }
        #endif
    }
    
    private func runPendingActionAfterDismiss() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            action()
        }
    }
    
    private func openMovieDetail(_ movie: Movie) {
        selectedMovie = movie
        #if !os(macOS)
        showMovieDetail = true
        #endif
    }
    
    private func openShowDetail(_ show: Show) {
        selectedShow = show
        #if !os(macOS)
        showShowDetail = true
        #endif
    }
    
    
    // MARK: - Hero Banner
    
    private func heroBanner(movie: Movie) -> some View {
        Button {
            gatedAction {
                openMovieDetail(movie)
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let url = movie.backdropURL ?? movie.posterURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ShimmerPlaceholder()
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        if let rating = movie.rating, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .foregroundColor(.white)
                            }
                            .font(.subheadline)
                        }
                        if let year = movie.year {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        if let genre = movie.genre {
                            Text(genre.components(separatedBy: ",").first ?? genre)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    if !premiumManager.isPremium {
                        premiumBadge
                    }
                }
                .padding()
                .padding(.bottom, 8)
            }
            .frame(height: heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, PlatformMetrics.contentPadding)
    }
    
    private var heroHeight: CGFloat {
        #if os(tvOS)
        return 400
        #elseif os(macOS)
        return 350
        #else
        return 220
        #endif
    }
    
    // MARK: - Continue Watching Section
    
    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Content.continueWatching, icon: "play.circle.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(continueWatchingItems) { item in
                        HomeContinueCard(item: item) {
                            gatedAction {
                                handleContinueWatching(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, sectionPadding)
            }
            .platformFocusSection()
        }
    }
    
    // MARK: - Trending Movies Section
    
    private var trendingMoviesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Content.trendingMovies, icon: "flame.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(Array(contentViewModel.trendingMovies.enumerated()), id: \.element.id) { index, movie in
                        TrendingCard(
                            title: movie.title,
                            posterURL: movie.posterURL,
                            rank: index + 1,
                            rating: movie.rating,
                            year: movie.year,
                            showLock: !premiumManager.isPremium
                        ) {
                            gatedAction {
                                openMovieDetail(movie)
                            }
                        }
                    }
                }
                .padding(.horizontal, sectionPadding)
            }
            .platformFocusSection()
        }
    }
    
    // MARK: - Trending Series Section
    
    private var trendingSeriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Content.trendingSeries, icon: "flame.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(Array(contentViewModel.trendingShows.enumerated()), id: \.element.id) { index, show in
                        TrendingCard(
                            title: show.title,
                            posterURL: show.posterURL,
                            rank: index + 1,
                            rating: show.rating,
                            year: show.year,
                            showLock: !premiumManager.isPremium
                        ) {
                            gatedAction {
                                openShowDetail(show)
                            }
                        }
                    }
                }
                .padding(.horizontal, sectionPadding)
            }
            .platformFocusSection()
        }
    }
    
    // MARK: - Trending Live TV Section
    
    private var trendingLiveTVSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: L10n.Content.trendingLiveTV, icon: "antenna.radiowaves.left.and.right")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(contentViewModel.trendingChannels) { channel in
                        ChannelCard(channel: channel, onTap: {
                            playingChannel = channel
                        })
                        .frame(width: PlatformMetrics.channelCardWidth)
                        .overlay(alignment: .topTrailing) {
                            if !premiumManager.isPremium {
                                premiumBadge
                                    .padding(6)
                            }
                        }
                    }
                }
                .padding(.horizontal, sectionPadding)
            }
            .platformFocusSection()
        }
    }
    
    // MARK: - My Favorites Section
    
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: L10n.Content.myFavorites, icon: "heart.fill")
            
            if !favoritesViewModel.favoriteChannels.isEmpty {
                favoritesRow(
                    title: L10n.Navigation.liveTV,
                    icon: "tv.fill",
                    iconColor: .blue
                ) {
                    ForEach(favoritesViewModel.favoriteChannels) { channel in
                        ChannelCard(channel: channel) {
                            playingChannel = channel
                        } onLongPress: {
                            contentViewModel.toggleFavorite(channel: channel)
                            favoritesViewModel.toggleFavorite(channel: channel)
                        }
                        .frame(width: PlatformMetrics.channelCardWidth)
                    }
                }
            }
            
            if !favoritesViewModel.favoriteMovies.isEmpty {
                favoritesRow(
                    title: L10n.Navigation.movies,
                    icon: "film.fill",
                    iconColor: .purple
                ) {
                    ForEach(favoritesViewModel.favoriteMovies) { movie in
                        MovieCard(movie: movie) {
                            gatedAction {
                                openMovieDetail(movie)
                            }
                        } onLongPress: {
                            contentViewModel.toggleFavorite(movie: movie)
                            favoritesViewModel.toggleFavorite(movie: movie)
                        }
                        .frame(width: PlatformMetrics.posterCardWidth)
                    }
                }
            }
            
            if !favoritesViewModel.favoriteShows.isEmpty {
                favoritesRow(
                    title: L10n.Navigation.shows,
                    icon: "play.rectangle.on.rectangle.fill",
                    iconColor: .orange
                ) {
                    ForEach(favoritesViewModel.favoriteShows) { show in
                        ShowCard(show: show) {
                            gatedAction {
                                openShowDetail(show)
                            }
                        } onLongPress: {
                            contentViewModel.toggleFavorite(show: show)
                            favoritesViewModel.toggleFavorite(show: show)
                        }
                        .frame(width: PlatformMetrics.posterCardWidth)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func reloadContinueWatching() {
        continueWatchingItems = StorageService.shared.getContinueWatching()
    }
    
    private func handleContinueWatching(_ item: StorageService.ContinueWatchingItem) {
        if item.contentType == "movie" {
            if let movie = contentViewModel.movie(withId: item.id) {
                #if os(macOS)
                movieToPlay = movie
                #else
                selectedMovie = movie
                #endif
                showMoviePlayer = true
            } else if let streamURL = item.streamURL {
                let movie = Movie(
                    id: item.id, title: item.title,
                    posterURL: item.posterURL, streamURL: streamURL,
                    category: "", year: nil, duration: Int(item.duration / 60),
                    description: nil, rating: nil, director: nil,
                    cast: nil, genre: nil, backdropURL: nil, streamId: nil
                )
                #if os(macOS)
                movieToPlay = movie
                #else
                selectedMovie = movie
                #endif
                showMoviePlayer = true
            }
        } else if let episodeId = item.episodeId {
            if let episode = contentViewModel.findEpisode(byId: episodeId) {
                if let showId = item.showId {
                    #if os(macOS)
                    showToPlay = contentViewModel.show(withId: showId)
                    #else
                    selectedShow = contentViewModel.show(withId: showId)
                    #endif
                }
                selectedEpisode = episode
                selectedSeasonNumber = item.seasonNumber
                showEpisodePlayer = true
            } else if let streamURL = item.streamURL {
                selectedEpisode = Episode(
                    id: episodeId,
                    episodeNumber: item.episodeNumber ?? 1,
                    title: item.episodeTitle ?? item.title,
                    thumbnailURL: item.posterURL,
                    streamURL: streamURL,
                    duration: Int(item.duration / 60)
                )
                if let showId = item.showId {
                    #if os(macOS)
                    showToPlay = contentViewModel.show(withId: showId)
                    #else
                    selectedShow = contentViewModel.show(withId: showId)
                    #endif
                }
                selectedSeasonNumber = item.seasonNumber
                showEpisodePlayer = true
            }
        }
    }
    
    // MARK: - Reusable Helpers
    
    private var sectionPadding: CGFloat {
        #if os(tvOS)
        return 50
        #else
        return PlatformMetrics.contentPadding
        #endif
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
            Text(title)
                .font(sectionTitleFont)
                .fontWeight(.bold)
        }
        .padding(.horizontal, sectionPadding)
    }
    
    private var sectionTitleFont: Font {
        #if os(tvOS)
        return .title
        #else
        return .title2
        #endif
    }
    
    private func favoritesRow<Content: View>(
        title: String, icon: String, iconColor: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, sectionPadding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    content()
                }
                .padding(.horizontal, sectionPadding)
            }
            .platformFocusSection()
        }
    }
    
    private var premiumBadge: some View {
        Text("PRO")
            .font(.caption2)
            .fontWeight(.heavy)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
    }
}

// MARK: - Continue Watching Card (enhanced with poster art)

struct HomeContinueCard: View {
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
    
    private var posterSize: CGFloat {
        #if os(tvOS)
        return 50
        #else
        return 40
        #endif
    }
    
    var body: some View {
        Button {
            onPlay()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Main image: snapshot (last frame) if available, otherwise poster
                    if let snapshotURL = item.snapshotURL,
                       FileManager.default.fileExists(atPath: snapshotURL.path) {
                        AsyncImage(url: snapshotURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            snapshotFallback
                        }
                        .frame(width: cardWidth, height: cardWidth * 9 / 16)
                        .clipped()
                    } else {
                        snapshotFallback
                    }
                    
                    // Play icon (centered)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                        .shadow(radius: 6)
                }
                .frame(width: cardWidth, height: cardWidth * 9 / 16)
                .overlay(alignment: .bottomTrailing) {
                    // Poster thumbnail in bottom-right
                    if let posterURL = item.posterURL {
                        CachedAsyncImage(url: posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: posterSize, height: posterSize * 1.5)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(6)
                    }
                }
                .overlay(alignment: .bottom) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.gray.opacity(0.5))
                            Rectangle().fill(Color.accentColor)
                                .frame(width: geo.size.width * item.progress)
                        }
                    }
                    .frame(height: 4)
                }
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.showTitle ?? item.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if item.contentType == "show" {
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
                        } else {
                            Text(item.contentType == "movie" ? "Movie" : "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 16)
                    
                    let remaining = max(0, item.duration - item.currentTime)
                    if remaining > 60 {
                        Text("\(Int(remaining / 60)) min left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                            .font(.caption2)
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
    
    @ViewBuilder
    private var snapshotFallback: some View {
        if let posterURL = item.posterURL {
            CachedAsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ShimmerPlaceholder()
            }
            .frame(width: cardWidth, height: cardWidth * 9 / 16)
            .clipped()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: cardWidth, height: cardWidth * 9 / 16)
                .overlay {
                    Image(systemName: item.contentType == "movie" ? "film" : "play.rectangle.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.4))
                }
        }
    }
}

// MARK: - Trending Card (Apple TV / Netflix "Top 10" style)

struct TrendingCard: View {
    let title: String
    let posterURL: URL?
    let rank: Int
    let rating: Double?
    let year: Int?
    var showLock: Bool = false
    var onTap: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    private var cardWidth: CGFloat {
        #if os(tvOS)
        return 180
        #elseif os(macOS)
        return 150
        #else
        return 130
        #endif
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomLeading) {
                    if let posterURL {
                        CachedAsyncImage(url: posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ShimmerPlaceholder()
                        }
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: "film")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                    }
                    
                    // Rank number
                    Text("\(rank)")
                        .font(.system(size: rankFontSize, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                        .offset(x: -4, y: 8)
                    
                    // Lock badge for free users
                    if showLock {
                        VStack {
                            HStack {
                                Spacer()
                                Text("PRO")
                                    .font(.caption2)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: cardWidth)
                .cornerRadius(12)
                .clipped()
                
                // Title
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: cardWidth, alignment: .leading)
                
                // Metadata
                HStack(spacing: 6) {
                    if let rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.0f%%", rating * 10))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    if let year {
                        Text(String(year))
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
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        #endif
    }
    
    private var rankFontSize: CGFloat {
        #if os(tvOS)
        return 64
        #elseif os(macOS)
        return 52
        #else
        return 44
        #endif
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
        .environmentObject(PremiumManager())
}
