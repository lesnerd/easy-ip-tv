import SwiftUI

/// Main Movies view with category navigation and lazy loading
struct MoviesView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var selectedCategory: ContentViewModel.CategoryInfo?
    @State private var selectedMovie: Movie?
    @State private var playingMovie: Movie?
    @State private var pendingPlayMovie: Movie?
    @State private var showUpgrade = false
    @State private var showInterstitial = false
    @State private var searchText = ""
    @State private var showSearchResults = false
    
    private var filteredMovies: [Movie] {
        guard !searchText.isEmpty else { return [] }
        return contentViewModel.allLoadedMovies.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if contentViewModel.isLoading {
                    LoadingView()
                } else if !contentViewModel.hasContent {
                    noContentView
                } else if showSearchResults && !searchText.isEmpty {
                    movieSearchResultsView
                } else if let category = selectedCategory {
                    categoryDetailView(category: category)
                } else {
                    categoryListView
                }
            }
            #if !os(tvOS)
            .navigationTitle(L10n.Navigation.movies)
            #endif
            .searchable(text: $searchText, prompt: L10n.Actions.search)
            .onChange(of: searchText) { _, newValue in
                showSearchResults = !newValue.isEmpty
            }
            .safeAreaInset(edge: .bottom) {
                BannerAdView { showUpgrade = true }
                    .environmentObject(premiumManager)
            }
        }
        .sheet(item: $selectedMovie, onDismiss: {
            if let movie = pendingPlayMovie {
                pendingPlayMovie = nil
                AdManager.shared.recordPlay()
                if AdManager.shared.showInterstitialIfNeeded(premiumManager: premiumManager) {
                    showInterstitial = true
                } else {
                    playingMovie = movie
                }
            }
        }) { movie in
            MovieDetailView(movie: movie) {
                pendingPlayMovie = movie
                selectedMovie = nil
            } onToggleFavorite: {
                toggleFavorite(movie)
            }
            .environmentObject(contentViewModel)
        }
        .platformFullScreen(item: $playingMovie) { movie in
            PlayerView(movie: movie, onClose: { playingMovie = nil })
                .id(movie.id)
                .environmentObject(contentViewModel)
        }
        .overlay {
            if showInterstitial {
                InterstitialAdOverlay(
                    onDismiss: { showInterstitial = false; if let m = pendingPlayMovie { pendingPlayMovie = nil; playingMovie = m } },
                    onUpgrade: { showInterstitial = false; showUpgrade = true }
                )
                .environmentObject(premiumManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85))
                .transition(.opacity)
                .zIndex(998)
            }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradePromptView()
                .environmentObject(premiumManager)
        }
    }
    
    // MARK: - Search Results View
    
    private var movieSearchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    searchText = ""
                    showSearchResults = false
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(L10n.Content.categories)
                    }
                    .font(.callout)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                CategoryHeader(
                    title: "\(L10n.Actions.search): \"\(searchText)\"",
                    icon: "magnifyingglass",
                    itemCount: filteredMovies.count
                )
                
                if filteredMovies.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No movies found matching \"\(searchText)\""
                    )
                } else {
                    CategoryGrid(items: filteredMovies, columns: PlatformMetrics.posterGridColumns) { movie in
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
                
                // Category rows
                ForEach(contentViewModel.vodCategories) { category in
                    MovieCategoryRowView(
                        category: category,
                        onSelectMovie: { selectMovie($0) },
                        onToggleFavorite: { toggleFavorite($0) },
                        onSeeAll: { selectedCategory = category }
                    )
                    .environmentObject(contentViewModel)
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
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var detailedMovie: Movie?
    @State private var isLoadingInfo = false
    @State private var isDescriptionExpanded = false
    @State private var showUpgradeForDownload = false
    @State private var showDownloadInterstitial = false
    
    private var displayMovie: Movie {
        detailedMovie ?? movie
    }
    
    var body: some View {
        ZStack {
            #if os(tvOS)
            tvOSDetailLayout
            #else
            adaptiveDetailLayout
            #endif
            
            downloadInterstitialOverlay
        }
    }
    
    #if os(tvOS)
    private var tvOSDetailLayout: some View {
        HStack(alignment: .top, spacing: 60) {
            posterView
                .frame(height: PlatformMetrics.detailPosterHeight)
            
            VStack(alignment: .leading, spacing: 24) {
                Text(displayMovie.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    if let year = displayMovie.year {
                        Text(String(year)).foregroundStyle(.secondary)
                    }
                    if let duration = displayMovie.duration {
                        Text(formatDuration(duration)).foregroundStyle(.secondary)
                    }
                    if let rating = displayMovie.rating, rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                        }
                    }
                    Text(displayMovie.category).foregroundStyle(.secondary)
                }
                .font(.callout)
                
                if let description = displayMovie.description, !description.isEmpty {
                    Text(description).font(.body).foregroundStyle(.secondary)
                }
                
                if let cast = displayMovie.cast, !cast.isEmpty {
                    Text("Starring: \(cast)").font(.callout).foregroundStyle(.secondary)
                }
                if let director = displayMovie.director, !director.isEmpty {
                    Text("Directed by: \(director)").font(.callout).foregroundStyle(.secondary)
                }
                
                HStack(spacing: 24) {
                    Button { onPlay() } label: {
                        Label(L10n.Player.play, systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button { onToggleFavorite() } label: {
                        Label(
                            displayMovie.isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                            systemImage: displayMovie.isFavorite ? "heart.fill" : "heart"
                        )
                    }
                    .buttonStyle(.bordered)
                    
                    movieDownloadButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(PlatformMetrics.detailPadding)
        .sheet(isPresented: $showUpgradeForDownload) {
            UpgradePromptView(reason: "You've reached the free limit of \(PremiumManager.freeMaxDownloads) downloads. Upgrade to Premium for unlimited downloads.")
                .environmentObject(premiumManager)
        }
    }
    #endif
    
    #if !os(tvOS)
    private var adaptiveDetailLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                #if os(iOS)
                // iPhone/iPad: poster as a top banner with gradient overlay
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(url: displayMovie.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "film")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .frame(height: 400)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    
                    LinearGradient(
                        colors: [.clear, .clear, Color(.systemBackground).opacity(0.6), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Title + metadata overlaid on poster
                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayMovie.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 12) {
                            if let rating = displayMovie.rating, rating > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(String(format: "%.0f%%", rating * 10))
                                        .fontWeight(.semibold)
                                }
                            }
                            if let year = displayMovie.year {
                                Text(String(year))
                            }
                            if let duration = displayMovie.duration {
                                Text(formatDuration(duration))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    if let description = displayMovie.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(isDescriptionExpanded ? nil : 3)
                            
                            if description.count > 120 {
                                Button(isDescriptionExpanded ? "Less" : "...More") {
                                    withAnimation { isDescriptionExpanded.toggle() }
                                }
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    // Watch button
                    Button {
                        onPlay()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("WATCH")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    movieDownloadButton
                    
                    // Loading indicator for detail info
                    if isLoadingInfo {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    
                    // Cast & Crew info
                    if let cast = displayMovie.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Starring")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(cast)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let director = displayMovie.director, !director.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Directed by")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(director)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let genre = displayMovie.genre, !genre.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Genre")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            HStack(spacing: 6) {
                                ForEach(genre.components(separatedBy: ", ").prefix(4), id: \.self) { g in
                                    Text(g)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Favorite button
                    Button {
                        onToggleFavorite()
                    } label: {
                        Label(
                            displayMovie.isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                            systemImage: displayMovie.isFavorite ? "heart.fill" : "heart"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(displayMovie.isFavorite ? .red : nil)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .sheet(isPresented: $showUpgradeForDownload) {
                    UpgradePromptView(reason: "You've reached the free limit of \(PremiumManager.freeMaxDownloads) downloads. Upgrade to Premium for unlimited downloads.")
                        .environmentObject(premiumManager)
                }
                #else
                // macOS: horizontal layout
                HStack(alignment: .top, spacing: 24) {
                    posterView
                        .frame(height: PlatformMetrics.detailPosterHeight)
                    macDetailContent
                }
                .padding(PlatformMetrics.detailPadding)
                #endif
            }
        }
        #if os(iOS)
        .ignoresSafeArea(edges: .top)
        #endif
        .task {
            guard !movie.isDetailLoaded, !isLoadingInfo else { return }
            isLoadingInfo = true
            if let updated = await contentViewModel.loadMovieInfo(for: movie) {
                detailedMovie = updated
            }
            isLoadingInfo = false
        }
    }
    #endif
    
    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "\(h)H \(m)M"
        }
        return "\(m)M"
    }
    
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
    
    #if !os(tvOS)
    private var macDetailContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(displayMovie.title)
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                if let year = displayMovie.year {
                    Text(String(year)).foregroundStyle(.secondary)
                }
                if let duration = displayMovie.duration {
                    Text(formatDuration(duration)).foregroundStyle(.secondary)
                }
                if let rating = displayMovie.rating, rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                    }
                }
                Text(displayMovie.category).foregroundStyle(.secondary)
            }
            .font(.callout)
            
            if let description = displayMovie.description, !description.isEmpty {
                Text(description).font(.body).foregroundStyle(.secondary)
            }
            
            if let cast = displayMovie.cast, !cast.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starring").font(.callout).fontWeight(.bold)
                    Text(cast).font(.callout).foregroundStyle(.secondary)
                }
            }
            
            if let director = displayMovie.director, !director.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Directed by").font(.callout).fontWeight(.bold)
                    Text(director).font(.callout).foregroundStyle(.secondary)
                }
            }
            
            if let genre = displayMovie.genre, !genre.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Genre").font(.callout).fontWeight(.bold)
                    Text(genre).font(.callout).foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 24) {
                Button { onPlay() } label: {
                    Label(L10n.Player.play, systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button { onToggleFavorite() } label: {
                    Label(
                        displayMovie.isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                        systemImage: displayMovie.isFavorite ? "heart.fill" : "heart"
                    )
                }
                .buttonStyle(.bordered)
                
                movieDownloadButton
            }
            
            if isLoadingInfo {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            guard !movie.isDetailLoaded, !isLoadingInfo else { return }
            isLoadingInfo = true
            if let updated = await contentViewModel.loadMovieInfo(for: movie) {
                detailedMovie = updated
            }
            isLoadingInfo = false
        }
        .sheet(isPresented: $showUpgradeForDownload) {
            UpgradePromptView(reason: "You've reached the free limit of \(PremiumManager.freeMaxDownloads) downloads. Upgrade to Premium for unlimited downloads.")
                .environmentObject(premiumManager)
        }
    }
    #endif
    
    @ViewBuilder
    private var movieDownloadButton: some View {
        let movieId = displayMovie.id
        if downloadManager.isDownloaded(id: movieId) {
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        } else if downloadManager.isDownloading(id: movieId) {
            if let progress = downloadManager.activeDownloads[movieId] {
                HStack(spacing: 8) {
                    ProgressView(value: progress.fractionCompleted)
                        .frame(width: 60)
                    Text("\(Int(progress.fractionCompleted * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        downloadManager.cancelDownload(id: movieId)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            Button {
                if !premiumManager.canDownload(currentCount: downloadManager.totalDownloadCount) {
                    showUpgradeForDownload = true
                } else if !premiumManager.isPremium {
                    let shown = AdManager.shared.showRealInterstitial { [self] in
                        downloadManager.startDownload(movie: displayMovie)
                    }
                    if !shown {
                        showDownloadInterstitial = true
                    }
                } else {
                    downloadManager.startDownload(movie: displayMovie)
                }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var downloadInterstitialOverlay: some View {
        Group {
            if showDownloadInterstitial {
                InterstitialAdOverlay(
                    onDismiss: {
                        showDownloadInterstitial = false
                        downloadManager.startDownload(movie: displayMovie)
                    },
                    onUpgrade: {
                        showDownloadInterstitial = false
                        showUpgradeForDownload = true
                    }
                )
                .environmentObject(premiumManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(999)
            }
        }
    }
}

// MARK: - Movie Category Row View (handles auto-loading)

private struct MovieCategoryRowView: View {
    let category: ContentViewModel.CategoryInfo
    var onSelectMovie: (Movie) -> Void
    var onToggleFavorite: (Movie) -> Void
    var onSeeAll: () -> Void
    
    @EnvironmentObject var contentViewModel: ContentViewModel
    @State private var hasRequestedLoad = false
    
    var body: some View {
        let movies = contentViewModel.movies(in: category.name)
        let isLoading = contentViewModel.isCategoryLoading(category)
        
        CategoryRow(
            title: category.name,
            itemCount: category.itemCount ?? movies.count
        ) {
            if movies.isEmpty {
                PosterLoadingPlaceholder(isLoading: isLoading, label: "Load Movies") {
                    Task { await contentViewModel.loadMoviesForCategory(category) }
                }
                .onAppear {
                    #if !os(tvOS)
                    guard !hasRequestedLoad else { return }
                    hasRequestedLoad = true
                    Task { await contentViewModel.loadMoviesForCategory(category) }
                    #endif
                }
            } else {
                ForEach(movies.prefix(PlatformMetrics.posterRowItemLimit)) { movie in
                    MovieCard(movie: movie) {
                        onSelectMovie(movie)
                    } onLongPress: {
                        onToggleFavorite(movie)
                    }
                    .frame(width: PlatformMetrics.posterCardWidth)
                }
                
                if movies.count > PlatformMetrics.posterRowItemLimit {
                    SeeAllButton(height: PlatformMetrics.posterCardWidth * 1.5) { onSeeAll() }
                }
            }
        }
    }
}

/// Poster-style loading placeholder (for movies/shows with 2:3 aspect ratio)
struct PosterLoadingPlaceholder: View {
    let isLoading: Bool
    let label: String
    var onTap: () -> Void = {}
    
    var body: some View {
        #if os(tvOS)
        Button {
            onTap()
        } label: {
            placeholderContent
        }
        .buttonStyle(CardButtonStyle())
        #else
        placeholderContent
        #endif
    }
    
    private var placeholderContent: some View {
        HStack(spacing: PlatformMetrics.horizontalSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCard(aspectRatio: 2/3)
                    .frame(width: PlatformMetrics.posterCardWidth)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
}

// MARK: - Metadata Pill

struct MetadataPill: View {
    let text: String
    var icon: String? = nil
    var tint: Color? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(tint ?? .secondary)
            }
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        #if os(iOS)
        .background(Color(.secondarySystemBackground))
        #else
        .background(Color.gray.opacity(0.2))
        #endif
        .cornerRadius(8)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }
        
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Preview

#Preview {
    MoviesView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
