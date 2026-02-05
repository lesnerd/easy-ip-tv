import SwiftUI

/// Main Shows view with category navigation and lazy loading
struct ShowsView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    @State private var selectedCategory: ContentViewModel.CategoryInfo?
    @State private var selectedShow: Show?
    @State private var showDetail = false
    @State private var selectedEpisode: Episode?
    @State private var selectedSeasonNumber: Int?
    @State private var showPlayer = false
    
    private var continueWatchingItems: [StorageService.ContinueWatchingItem] {
        StorageService.shared.getContinueWatching().filter { $0.contentType == "show" }
    }
    
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
            .navigationTitle(L10n.Navigation.shows)
        }
        .sheet(isPresented: $showDetail) {
            if let show = selectedShow {
                ShowDetailView(show: show) { episode, seasonNumber in
                    selectedEpisode = episode
                    selectedSeasonNumber = seasonNumber
                    showDetail = false
                    showPlayer = true
                } onToggleFavorite: {
                    toggleFavorite(show)
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let episode = selectedEpisode {
                PlayerView(episode: episode, showContext: selectedShow, seasonNumber: selectedSeasonNumber)
            }
        }
    }
    
    // MARK: - Category List View
    
    private var categoryListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                // Continue Watching row
                if !continueWatchingItems.isEmpty {
                    ContinueWatchingRow(
                        items: continueWatchingItems,
                        onPlayItem: { item in
                            // Find the episode and play it
                            if let episodeId = item.episodeId {
                                // Create a temporary episode to play
                                // In a real app, you'd fetch the full episode data
                                let episode = Episode(
                                    id: episodeId,
                                    episodeNumber: item.episodeNumber ?? 1,
                                    title: item.episodeTitle ?? item.title,
                                    streamURL: URL(string: "placeholder")!, // Would need to store/fetch this
                                    watchProgress: item.progress
                                )
                                selectedEpisode = episode
                                showPlayer = true
                            }
                        }
                    )
                }
                
                // Featured Shows row (if any loaded)
                if !contentViewModel.featuredShows.isEmpty {
                    CategoryRow(
                        title: L10n.Content.featured,
                        icon: "star.fill",
                        itemCount: contentViewModel.featuredShows.count
                    ) {
                        ForEach(contentViewModel.featuredShows.prefix(8)) { show in
                            ShowCard(show: show) {
                                selectShow(show)
                            } onLongPress: {
                                toggleFavorite(show)
                            }
                            .frame(width: 200)
                        }
                    }
                }
                
                // Category rows - tap to load
                ForEach(contentViewModel.seriesCategories) { category in
                    let shows = contentViewModel.shows(in: category.name)
                    
                    CategoryRow(
                        title: category.name,
                        itemCount: category.itemCount ?? shows.count
                    ) {
                        if shows.isEmpty {
                            // Show loading placeholder or tap to load
                            Button {
                                Task {
                                    await contentViewModel.loadShowsForCategory(category)
                                }
                            } label: {
                                VStack {
                                    if contentViewModel.isLoadingCategory {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.largeTitle)
                                        Text("Load Shows")
                                            .font(.callout)
                                    }
                                }
                                .frame(width: 200, height: 300)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            }
                            .buttonStyle(CardButtonStyle())
                        } else {
                            ForEach(shows.prefix(8)) { show in
                                ShowCard(show: show) {
                                    selectShow(show)
                                } onLongPress: {
                                    toggleFavorite(show)
                                }
                                .frame(width: 200)
                            }
                            
                            // See more button
                            if shows.count > 8 {
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
            }
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Category Detail View
    
    private func categoryDetailView(category: ContentViewModel.CategoryInfo) -> some View {
        let shows = contentViewModel.shows(in: category.name)
        
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
                CategoryHeader(title: category.name, icon: "play.rectangle.on.rectangle", itemCount: shows.count)
                
                if contentViewModel.isLoadingCategory {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else if shows.isEmpty {
                    // Auto-load when navigating to detail
                    Color.clear.onAppear {
                        Task {
                            await contentViewModel.loadShowsForCategory(category)
                        }
                    }
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else {
                    // Show grid
                    CategoryGrid(items: shows, columns: 6) { show in
                        ShowCard(show: show) {
                            selectShow(show)
                        } onLongPress: {
                            toggleFavorite(show)
                        }
                    }
                }
            }
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - No Content View
    
    private var noContentView: some View {
        EmptyStateView(
            icon: "play.rectangle.on.rectangle.slash",
            title: L10n.Errors.noPlaylist,
            message: L10n.Errors.noPlaylistDescription
        )
    }
    
    // MARK: - Actions
    
    private func selectShow(_ show: Show) {
        selectedShow = show
        showDetail = true
    }
    
    private func toggleFavorite(_ show: Show) {
        contentViewModel.toggleFavorite(show: show)
        favoritesViewModel.toggleFavorite(show: show)
    }
}

// MARK: - Show Detail View

struct ShowDetailView: View {
    let show: Show
    var onPlayEpisode: (Episode, Int?) -> Void = { _, _ in }
    var onToggleFavorite: () -> Void = {}
    
    @State private var selectedSeason: Season?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(alignment: .top, spacing: 60) {
            // Poster
            CachedAsyncImage(url: show.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                    }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .frame(height: 400)
            .cornerRadius(16)
            
            // Details and Episodes
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text(show.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Metadata
                HStack(spacing: 16) {
                    if let year = show.year {
                        Text(String(year))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("\(show.seasons.count) Seasons")
                        .foregroundStyle(.secondary)
                    
                    Text("\(show.totalEpisodes) Episodes")
                        .foregroundStyle(.secondary)
                    
                    if let rating = show.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                        }
                    }
                }
                .font(.callout)
                
                // Description
                if let description = show.description {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                // Favorite button
                Button {
                    onToggleFavorite()
                } label: {
                    Label(
                        show.isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                        systemImage: show.isFavorite ? "heart.fill" : "heart"
                    )
                }
                .buttonStyle(.bordered)
                
                Divider()
                
                // Season picker
                if !show.seasons.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(show.seasons) { season in
                                Button {
                                    selectedSeason = season
                                } label: {
                                    Text(season.displayTitle)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedSeason?.id == season.id ?
                                            Color.accentColor : Color.gray.opacity(0.3)
                                        )
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Episodes list
                    if let season = selectedSeason ?? show.seasons.first {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(season.episodes) { episode in
                                    EpisodeRowView(episode: episode) {
                                        onPlayEpisode(episode, season.seasonNumber)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(60)
        .onAppear {
            selectedSeason = show.seasons.first
        }
    }
}

// MARK: - Episode Row View

struct EpisodeRowView: View {
    let episode: Episode
    var onPlay: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onPlay()
        } label: {
            HStack(spacing: 16) {
                // Episode number
                Text("E\(episode.episodeNumber)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                
                // Thumbnail
                CachedAsyncImage(url: episode.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "play.fill")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 120, height: 68)
                .cornerRadius(6)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.callout)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let duration = episode.duration {
                            Text("\(duration) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Progress bar
                        if episode.watchProgress > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(width: geo.size.width * episode.watchProgress)
                                }
                            }
                            .frame(width: 80, height: 4)
                            .cornerRadius(2)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(isFocused ? 0.2 : 0.1))
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Continue Watching Row

struct ContinueWatchingRow: View {
    let items: [StorageService.ContinueWatchingItem]
    var onPlayItem: (StorageService.ContinueWatchingItem) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CategoryHeader(
                title: L10n.Content.continueWatching,
                icon: "play.circle",
                itemCount: items.count
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(items) { item in
                        ContinueWatchingCard(item: item) {
                            onPlayItem(item)
                        }
                    }
                }
                .padding(.horizontal, 50)
            }
        }
    }
}

// MARK: - Continue Watching Card

struct ContinueWatchingCard: View {
    let item: StorageService.ContinueWatchingItem
    var onPlay: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onPlay()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail placeholder with play icon
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    Image(systemName: "play.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    
                    // Progress bar at bottom
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
                .frame(width: 280)
                .cornerRadius(12)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let season = item.seasonNumber, let episode = item.episodeNumber {
                            Text("S\(season) E\(episode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let episodeTitle = item.episodeTitle {
                            Text(episodeTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Time remaining
                    let remaining = item.duration - item.currentTime
                    if remaining > 0 {
                        Text("\(Int(remaining / 60)) min remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 280, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Preview

#Preview {
    ShowsView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
