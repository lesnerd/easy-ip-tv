import SwiftUI

/// Main Movies view with category navigation and lazy loading
struct MoviesView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    @State private var selectedCategory: ContentViewModel.CategoryInfo?
    @State private var selectedMovie: Movie?
    @State private var showDetail = false
    @State private var showPlayer = false
    
    var body: some View {
        NavigationStack {
            Group {
                if contentViewModel.isLoading {
                    LoadingView()
                } else if !contentViewModel.hasContent {
                    noContentView
                } else if let category = selectedCategory {
                    categoryDetailView(category: category)
                } else {
                    categoryListView
                }
            }
            .navigationTitle(L10n.Navigation.movies)
        }
        .sheet(isPresented: $showDetail) {
            if let movie = selectedMovie {
                MovieDetailView(movie: movie) {
                    showDetail = false
                    showPlayer = true
                } onToggleFavorite: {
                    toggleFavorite(movie)
                }
            }
        }
        .platformFullScreen(isPresented: $showPlayer) {
            if let movie = selectedMovie {
                PlayerView(movie: movie)
            }
        }
    }
    
    // MARK: - Category List View
    
    private var categoryListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PlatformMetrics.sectionSpacing) {
                // Featured Movies row
                if !contentViewModel.featuredMovies.isEmpty {
                    CategoryRow(
                        title: L10n.Content.featured,
                        icon: "star.fill",
                        itemCount: contentViewModel.featuredMovies.count
                    ) {
                        ForEach(contentViewModel.featuredMovies.prefix(PlatformMetrics.posterRowItemLimit)) { movie in
                            MovieCard(movie: movie) {
                                selectMovie(movie)
                            } onLongPress: {
                                toggleFavorite(movie)
                            }
                            .frame(width: PlatformMetrics.posterCardWidth)
                        }
                    }
                }
                
                // Category rows - tap to load
                ForEach(contentViewModel.vodCategories) { category in
                    let movies = contentViewModel.movies(in: category.name)
                    
                    CategoryRow(
                        title: category.name,
                        itemCount: category.itemCount ?? movies.count
                    ) {
                        if movies.isEmpty {
                            // Show loading placeholder or tap to load
                            Button {
                                Task {
                                    await contentViewModel.loadMoviesForCategory(category)
                                }
                            } label: {
                                VStack {
                                    if contentViewModel.isLoadingCategory {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.largeTitle)
                                        Text("Load Movies")
                                            .font(.callout)
                                    }
                                }
                                .frame(width: PlatformMetrics.posterCardWidth, height: PlatformMetrics.posterCardWidth * 1.5)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            }
                            .buttonStyle(CardButtonStyle())
                        } else {
                            ForEach(movies.prefix(PlatformMetrics.posterRowItemLimit)) { movie in
                                MovieCard(movie: movie) {
                                    selectMovie(movie)
                                } onLongPress: {
                                    toggleFavorite(movie)
                                }
                                .frame(width: PlatformMetrics.posterCardWidth)
                            }
                            
                            // See more button
                            if movies.count > PlatformMetrics.posterRowItemLimit {
                                Button {
                                    selectedCategory = category
                                } label: {
                                    VStack {
                                        Image(systemName: "ellipsis")
                                            .font(.largeTitle)
                                        Text(L10n.Content.seeAll)
                                            .font(.callout)
                                    }
                                    .frame(width: 150, height: PlatformMetrics.posterCardWidth * 1.5)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(CardButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(.vertical, PlatformMetrics.contentPadding)
        }
    }
    
    // MARK: - Category Detail View
    
    private func categoryDetailView(category: ContentViewModel.CategoryInfo) -> some View {
        let movies = contentViewModel.movies(in: category.name)
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Back button
                Button {
                    selectedCategory = nil
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(L10n.Content.categories)
                    }
                    .font(.callout)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                // Category header
                CategoryHeader(title: category.name, icon: "film", itemCount: movies.count)
                
                if contentViewModel.isLoadingCategory {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else if movies.isEmpty {
                    // Auto-load when navigating to detail
                    Color.clear.onAppear {
                        Task {
                            await contentViewModel.loadMoviesForCategory(category)
                        }
                    }
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else {
                    // Movie grid
                    CategoryGrid(items: movies, columns: PlatformMetrics.posterGridColumns) { movie in
                        MovieCard(movie: movie) {
                            selectMovie(movie)
                        } onLongPress: {
                            toggleFavorite(movie)
                        }
                    }
                }
            }
            .padding(.vertical, PlatformMetrics.contentPadding)
        }
    }
    
    // MARK: - No Content View
    
    private var noContentView: some View {
        EmptyStateView(
            icon: "film.slash",
            title: L10n.Errors.noPlaylist,
            message: L10n.Errors.noPlaylistDescription
        )
    }
    
    // MARK: - Actions
    
    private func selectMovie(_ movie: Movie) {
        selectedMovie = movie
        showDetail = true
    }
    
    private func toggleFavorite(_ movie: Movie) {
        contentViewModel.toggleFavorite(movie: movie)
        favoritesViewModel.toggleFavorite(movie: movie)
    }
}

// MARK: - Movie Detail View

struct MovieDetailView: View {
    let movie: Movie
    var onPlay: () -> Void = {}
    var onToggleFavorite: () -> Void = {}
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        #if os(tvOS)
        tvOSDetailLayout
        #else
        adaptiveDetailLayout
        #endif
    }
    
    #if os(tvOS)
    private var tvOSDetailLayout: some View {
        HStack(alignment: .top, spacing: 60) {
            posterView
                .frame(height: PlatformMetrics.detailPosterHeight)
            
            detailContent
            Spacer()
        }
        .padding(PlatformMetrics.detailPadding)
    }
    #endif
    
    #if !os(tvOS)
    private var adaptiveDetailLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    posterView
                        .frame(height: PlatformMetrics.detailPosterHeight)
                    
                    detailContent
                }
            }
            .padding(PlatformMetrics.detailPadding)
        }
    }
    #endif
    
    private var posterView: some View {
        CachedAsyncImage(url: movie.posterURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay {
                    Image(systemName: "film")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .cornerRadius(16)
    }
    
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title
            Text(movie.title)
                .font(.title)
                .fontWeight(.bold)
            
            // Metadata
            HStack(spacing: 16) {
                if let year = movie.year {
                    Text(String(year))
                        .foregroundStyle(.secondary)
                }
                
                if let duration = movie.duration {
                    Text("\(duration) min")
                        .foregroundStyle(.secondary)
                }
                
                if let rating = movie.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                    }
                }
                
                Text(movie.category)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            
            // Description
            if let description = movie.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 24) {
                Button {
                    onPlay()
                } label: {
                    Label(L10n.Player.play, systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    onToggleFavorite()
                } label: {
                    Label(
                        movie.isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                        systemImage: movie.isFavorite ? "heart.fill" : "heart"
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    MoviesView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
