import SwiftUI

/// Favorites view showing all favorited content grouped by category
struct FavoritesView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    @State private var selectedChannel: Channel?
    @State private var selectedMovie: Movie?
    @State private var selectedShow: Show?
    @State private var showChannelPlayer = false
    @State private var showMoviePlayer = false
    @State private var showMovieDetail = false
    @State private var showShowDetail = false
    @State private var selectedEpisode: Episode?
    @State private var showEpisodePlayer = false
    
    var body: some View {
        NavigationStack {
            Group {
                if !favoritesViewModel.hasFavorites {
                    emptyView
                } else {
                    contentView
                }
            }
            .navigationTitle(L10n.Navigation.favorites)
        }
        .fullScreenCover(isPresented: $showChannelPlayer) {
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
        .fullScreenCover(isPresented: $showMoviePlayer) {
            if let movie = selectedMovie {
                PlayerView(movie: movie)
            }
        }
        .sheet(isPresented: $showShowDetail) {
            if let show = selectedShow {
                ShowDetailView(show: show) { episode in
                    selectedEpisode = episode
                    showShowDetail = false
                    showEpisodePlayer = true
                } onToggleFavorite: {
                    toggleFavorite(show: show)
                }
            }
        }
        .fullScreenCover(isPresented: $showEpisodePlayer) {
            if let episode = selectedEpisode {
                PlayerView(episode: episode)
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                // Favorite Channels by Category
                if !favoritesViewModel.favoriteChannels.isEmpty {
                    ForEach(favoritesViewModel.favoriteChannelsByCategory.keys.sorted(), id: \.self) { category in
                        if let channels = favoritesViewModel.favoriteChannelsByCategory[category] {
                            CategoryRow(
                                title: category,
                                icon: "tv",
                                itemCount: channels.count
                            ) {
                                ForEach(channels) { channel in
                                    ChannelCard(channel: channel) {
                                        playChannel(channel)
                                    } onLongPress: {
                                        toggleFavorite(channel: channel)
                                    }
                                    .frame(width: 300)
                                }
                            }
                        }
                    }
                }
                
                // Favorite Movies by Category
                if !favoritesViewModel.favoriteMovies.isEmpty {
                    ForEach(favoritesViewModel.favoriteMoviesByCategory.keys.sorted(), id: \.self) { category in
                        if let movies = favoritesViewModel.favoriteMoviesByCategory[category] {
                            CategoryRow(
                                title: category,
                                icon: "film",
                                itemCount: movies.count
                            ) {
                                ForEach(movies) { movie in
                                    MovieCard(movie: movie) {
                                        selectMovie(movie)
                                    } onLongPress: {
                                        toggleFavorite(movie: movie)
                                    }
                                    .frame(width: 200)
                                }
                            }
                        }
                    }
                }
                
                // Favorite Shows by Category
                if !favoritesViewModel.favoriteShows.isEmpty {
                    ForEach(favoritesViewModel.favoriteShowsByCategory.keys.sorted(), id: \.self) { category in
                        if let shows = favoritesViewModel.favoriteShowsByCategory[category] {
                            CategoryRow(
                                title: category,
                                icon: "play.rectangle.on.rectangle",
                                itemCount: shows.count
                            ) {
                                ForEach(shows) { show in
                                    ShowCard(show: show) {
                                        selectShow(show)
                                    } onLongPress: {
                                        toggleFavorite(show: show)
                                    }
                                    .frame(width: 200)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 40)
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

// MARK: - Preview

#Preview {
    FavoritesView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
