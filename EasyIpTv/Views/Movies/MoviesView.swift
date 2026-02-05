import SwiftUI

/// Main Movies view with category navigation
struct MoviesView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    @State private var selectedCategory: String?
    @State private var selectedMovie: Movie?
    @State private var showDetail = false
    @State private var showPlayer = false
    
    var body: some View {
        NavigationStack {
            Group {
                if contentViewModel.isLoading {
                    LoadingView()
                } else if contentViewModel.movies.isEmpty {
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
        .fullScreenCover(isPresented: $showPlayer) {
            if let movie = selectedMovie {
                PlayerView(movie: movie)
            }
        }
    }
    
    // MARK: - Category List View
    
    private var categoryListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                // All Movies row
                CategoryRow(
                    title: L10n.Content.allMovies,
                    icon: "film",
                    itemCount: contentViewModel.movies.count
                ) {
                    ForEach(contentViewModel.movies.prefix(8)) { movie in
                        MovieCard(movie: movie) {
                            selectMovie(movie)
                        } onLongPress: {
                            toggleFavorite(movie)
                        }
                        .frame(width: 200)
                    }
                }
                
                // Category rows
                ForEach(contentViewModel.movieCategories, id: \.self) { category in
                    let movies = contentViewModel.movies(in: category)
                    
                    CategoryRow(
                        title: category,
                        itemCount: movies.count
                    ) {
                        ForEach(movies.prefix(8)) { movie in
                            MovieCard(movie: movie) {
                                selectMovie(movie)
                            } onLongPress: {
                                toggleFavorite(movie)
                            }
                            .frame(width: 200)
                        }
                        
                        // See more button
                        if movies.count > 8 {
                            Button {
                                selectedCategory = category
                            } label: {
                                VStack {
                                    Image(systemName: "ellipsis")
                                        .font(.largeTitle)
                                    Text("See All")
                                        .font(.callout)
                                }
                                .frame(width: 150, height: 300)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            }
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                }
            }
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Category Detail View
    
    private func categoryDetailView(category: String) -> some View {
        let movies = contentViewModel.movies(in: category)
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 30) {
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
                CategoryHeader(title: category, icon: "film", itemCount: movies.count)
                
                // Movie grid
                CategoryGrid(items: movies, columns: 6) { movie in
                    MovieCard(movie: movie) {
                        selectMovie(movie)
                    } onLongPress: {
                        toggleFavorite(movie)
                    }
                }
            }
            .padding(.vertical, 40)
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
        HStack(alignment: .top, spacing: 60) {
            // Poster
            AsyncImage(url: movie.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "film")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .frame(height: 500)
            .cornerRadius(16)
            
            // Details
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
            
            Spacer()
        }
        .padding(60)
    }
}

// MARK: - Preview

#Preview {
    MoviesView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
