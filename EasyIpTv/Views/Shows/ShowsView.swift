import SwiftUI

/// Main Shows view with category navigation and lazy loading
struct ShowsView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var selectedCategory: ContentViewModel.CategoryInfo?
    @State private var selectedShow: Show?
    @State private var selectedEpisode: Episode?
    @State private var selectedSeasonNumber: Int?
    @State private var playingEpisode: Episode?
    @State private var pendingPlayEpisode: Episode?
    @State private var pendingSeasonNumber: Int?
    @State private var showUpgrade = false
    @State private var showInterstitial = false
    @State private var searchText = ""
    @State private var showSearchResults = false
    
    private var continueWatchingItems: [StorageService.ContinueWatchingItem] {
        StorageService.shared.getContinueWatching().filter { $0.contentType == "show" }
    }
    
    private var filteredShows: [Show] {
        guard !searchText.isEmpty else { return [] }
        return contentViewModel.allLoadedShows.filter {
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
                    showSearchResultsView
                } else if let category = selectedCategory {
                    categoryDetailView(category: category)
                } else {
                    categoryListView
                }
            }
            #if !os(tvOS)
            .navigationTitle(L10n.Navigation.shows)
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
        .sheet(item: $selectedShow, onDismiss: {
            NSLog("[ShowsView] sheet onDismiss, pendingPlayEpisode=%@", pendingPlayEpisode?.title ?? "nil")
            if let episode = pendingPlayEpisode {
                pendingPlayEpisode = nil
                selectedSeasonNumber = pendingSeasonNumber
                AdManager.shared.recordPlay()
                if AdManager.shared.showInterstitialIfNeeded(premiumManager: premiumManager) {
                    showInterstitial = true
                } else {
                    NSLog("[ShowsView] Setting playingEpisode=%@ url=%@", episode.title, episode.streamURL.absoluteString)
                    playingEpisode = episode
                }
            }
        }) { show in
            ShowDetailView(show: show) { episode, seasonNumber in
                NSLog("[ShowsView] Episode play tapped: %@ url=%@", episode.title, episode.streamURL.absoluteString)
                selectedEpisode = episode
                pendingPlayEpisode = episode
                pendingSeasonNumber = seasonNumber
                selectedShow = nil
            } onToggleFavorite: {
                toggleFavorite(show)
            }
            .environmentObject(contentViewModel)
        }
        .platformFullScreen(item: $playingEpisode) { episode in
            PlayerView(episode: episode, showContext: selectedShow, seasonNumber: selectedSeasonNumber, onClose: { playingEpisode = nil })
                .id(episode.id)
                .environmentObject(contentViewModel)
        }
        .overlay {
            if showInterstitial {
                InterstitialAdOverlay(
                    onDismiss: { showInterstitial = false; if let ep = pendingPlayEpisode { pendingPlayEpisode = nil; playingEpisode = ep } },
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
    
    private var showSearchResultsView: some View {
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
                    itemCount: filteredShows.count
                )
                
                if filteredShows.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No shows found matching \"\(searchText)\""
                    )
                } else {
                    CategoryGrid(items: filteredShows, columns: PlatformMetrics.posterGridColumns) { show in
                        ShowCard(show: show) {
                            selectShow(show)
                        } onLongPress: {
                            toggleFavorite(show)
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
                // Continue Watching row
                if !continueWatchingItems.isEmpty {
                    ContinueWatchingRow(
                        items: continueWatchingItems,
                        onPlayItem: { item in
                            if let episodeId = item.episodeId,
                               let resolvedEpisode = contentViewModel.findEpisode(byId: episodeId) {
                                selectedEpisode = resolvedEpisode
                                playingEpisode = resolvedEpisode
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
                        ForEach(contentViewModel.featuredShows.prefix(PlatformMetrics.posterRowItemLimit)) { show in
                            ShowCard(show: show) {
                                selectShow(show)
                            } onLongPress: {
                                toggleFavorite(show)
                            }
                            .frame(width: PlatformMetrics.posterCardWidth)
                        }
                    }
                }
                
                // Category rows - tap to load
                // Category rows - auto-load on appear (macOS/iOS) or tap to load (tvOS)
                ForEach(contentViewModel.seriesCategories) { category in
                    ShowCategoryRowView(
                        category: category,
                        onSelectShow: { selectShow($0) },
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
        let shows = contentViewModel.shows(in: category.name)
        
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
                CategoryHeader(title: category.name, icon: "play.rectangle.on.rectangle", itemCount: shows.count)
                
                if contentViewModel.isLoadingCategory {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else if shows.isEmpty {
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
                    CategoryGrid(items: shows, columns: PlatformMetrics.posterGridColumns) { show in
                        ShowCard(show: show) {
                            selectShow(show)
                        } onLongPress: {
                            toggleFavorite(show)
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
            icon: "play.rectangle.on.rectangle.slash",
            title: L10n.Errors.noPlaylist,
            message: L10n.Errors.noPlaylistDescription
        )
    }
    
    // MARK: - Actions
    
    private func selectShow(_ show: Show) {
        selectedShow = show
    }
    
    private func toggleFavorite(_ show: Show) {
        contentViewModel.toggleFavorite(show: show)
        favoritesViewModel.toggleFavorite(show: show)
    }
}

// MARK: - Show Detail View

struct ShowDetailView: View {
    @State private var show: Show
    var onPlayEpisode: (Episode, Int?) -> Void = { _, _ in }
    var onToggleFavorite: () -> Void = {}
    
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var selectedSeason: Season?
    @State private var isLoadingEpisodes = false
    @State private var showUpgradeForDownload = false
    @State private var showDownloadInterstitial = false
    @State private var pendingDownloadEpisode: Episode?
    @State private var pendingDownloadSeasonNumber: Int?
    @Environment(\.dismiss) private var dismiss
    
    init(show: Show, onPlayEpisode: @escaping (Episode, Int?) -> Void = { _, _ in }, onToggleFavorite: @escaping () -> Void = {}) {
        self._show = State(initialValue: show)
        self.onPlayEpisode = onPlayEpisode
        self.onToggleFavorite = onToggleFavorite
    }
    
    var body: some View {
        ZStack {
            #if os(tvOS)
            tvOSLayout
            #else
            adaptiveLayout
            #endif
            
            if showDownloadInterstitial {
                InterstitialAdOverlay(
                    onDismiss: {
                        showDownloadInterstitial = false
                        if let ep = pendingDownloadEpisode, let sn = pendingDownloadSeasonNumber {
                            downloadManager.startDownload(episode: ep, showTitle: show.title, showId: show.id, seasonNumber: sn)
                            pendingDownloadEpisode = nil
                            pendingDownloadSeasonNumber = nil
                        }
                    },
                    onUpgrade: {
                        showDownloadInterstitial = false
                        pendingDownloadEpisode = nil
                        pendingDownloadSeasonNumber = nil
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
    
    #if os(tvOS)
    private var tvOSLayout: some View {
        HStack(alignment: .top, spacing: 60) {
            posterView
                .frame(height: PlatformMetrics.showDetailPosterHeight)
            if isLoadingEpisodes {
                VStack {
                    ProgressView("Loading episodes...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                detailContent
            }
        }
        .padding(PlatformMetrics.detailPadding)
        .task {
            await loadEpisodesIfNeeded()
        }
    }
    #endif
    
    #if !os(tvOS)
    private var adaptiveLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    posterView
                        .frame(height: PlatformMetrics.showDetailPosterHeight)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        showHeader
                        favoriteButton
                    }
                }
                
                Divider()
                
                if isLoadingEpisodes {
                    ProgressView("Loading episodes...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    seasonsAndEpisodes
                }
            }
            .padding(PlatformMetrics.detailPadding)
        }
        .task {
            await loadEpisodesIfNeeded()
        }
    }
    #endif
    
    private var posterView: some View {
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
        .cornerRadius(16)
    }
    
    private var showHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(show.title)
                .font(.title)
                .fontWeight(.bold)
            
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
            
            if let description = show.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
    
    private var favoriteButton: some View {
        Button {
            onToggleFavorite()
        } label: {
            Label(
                show.isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                systemImage: show.isFavorite ? "heart.fill" : "heart"
            )
        }
        .buttonStyle(.bordered)
    }
    
    private func loadEpisodesIfNeeded() async {
        guard show.seasons.isEmpty else {
            selectedSeason = show.seasons.first
            return
        }
        isLoadingEpisodes = true
        if let updatedShow = await contentViewModel.loadSeriesInfo(for: show) {
            show = updatedShow
            selectedSeason = updatedShow.seasons.first
        }
        isLoadingEpisodes = false
    }
    
    private var seasonsAndEpisodes: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    LazyVStack(spacing: 8) {
                        ForEach(season.episodes) { episode in
                            EpisodeRowView(
                                episode: episode,
                                onPlay: { onPlayEpisode(episode, season.seasonNumber) },
                                downloadState: episodeDownloadState(episode),
                                onDownload: { downloadEpisode(episode, seasonNumber: season.seasonNumber) },
                                onCancelDownload: { downloadManager.cancelDownload(id: episode.id) }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showUpgradeForDownload) {
            UpgradePromptView()
                .environmentObject(premiumManager)
        }
    }
    
    private func episodeDownloadState(_ episode: Episode) -> EpisodeDownloadState {
        if downloadManager.isDownloaded(id: episode.id) { return .downloaded }
        if downloadManager.isDownloading(id: episode.id) { return .downloading(downloadManager.activeDownloads[episode.id]?.fractionCompleted ?? 0) }
        return .notDownloaded
    }
    
    private func downloadEpisode(_ episode: Episode, seasonNumber: Int) {
        if !premiumManager.canDownload(currentCount: downloadManager.totalDownloadCount) {
            showUpgradeForDownload = true
        } else if !premiumManager.isPremium {
            let shown = AdManager.shared.showRealInterstitial { [self] in
                downloadManager.startDownload(
                    episode: episode,
                    showTitle: show.title,
                    showId: show.id,
                    seasonNumber: seasonNumber
                )
            }
            if !shown {
                pendingDownloadEpisode = episode
                pendingDownloadSeasonNumber = seasonNumber
                showDownloadInterstitial = true
            }
        } else {
            downloadManager.startDownload(
                episode: episode,
                showTitle: show.title,
                showId: show.id,
                seasonNumber: seasonNumber
            )
        }
    }
    
    // tvOS uses combined layout
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            showHeader
            favoriteButton
            Divider()
            seasonsAndEpisodes
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Episode Download State

enum EpisodeDownloadState {
    case notDownloaded
    case downloading(Double)
    case downloaded
}

// MARK: - Episode Row View

struct EpisodeRowView: View {
    let episode: Episode
    var onPlay: () -> Void = {}
    var downloadState: EpisodeDownloadState = .notDownloaded
    var onDownload: (() -> Void)?
    var onCancelDownload: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onPlay()
        } label: {
            HStack(spacing: 16) {
                Text("E\(episode.episodeNumber)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
                
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
                
                episodeDownloadIndicator
                
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
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #endif
    }
    
    @ViewBuilder
    private var episodeDownloadIndicator: some View {
        switch downloadState {
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 30)
                if let onCancelDownload {
                    Button {
                        onCancelDownload()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .notDownloaded:
            if let onDownload {
                Button {
                    onDownload()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
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
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(items) { item in
                        ContinueWatchingCard(item: item) {
                            onPlayItem(item)
                        }
                    }
                }
                .padding(.horizontal, PlatformMetrics.contentPadding + 10)
            }
        }
    }
}

// MARK: - Continue Watching Card

struct ContinueWatchingCard: View {
    let item: StorageService.ContinueWatchingItem
    var onPlay: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    private var cardWidth: CGFloat {
        #if os(tvOS)
        return 280
        #elseif os(macOS)
        return 240
        #else
        return 200
        #endif
    }
    
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
                .frame(width: cardWidth)
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

// MARK: - Show Category Row View (handles auto-loading)

private struct ShowCategoryRowView: View {
    let category: ContentViewModel.CategoryInfo
    var onSelectShow: (Show) -> Void
    var onToggleFavorite: (Show) -> Void
    var onSeeAll: () -> Void
    
    @EnvironmentObject var contentViewModel: ContentViewModel
    @State private var hasRequestedLoad = false
    
    var body: some View {
        let shows = contentViewModel.shows(in: category.name)
        let isLoading = contentViewModel.isCategoryLoading(category)
        
        CategoryRow(
            title: category.name,
            itemCount: category.itemCount ?? shows.count
        ) {
            if shows.isEmpty {
                PosterLoadingPlaceholder(isLoading: isLoading, label: "Load Shows") {
                    Task { await contentViewModel.loadShowsForCategory(category) }
                }
                .onAppear {
                    #if !os(tvOS)
                    guard !hasRequestedLoad else { return }
                    hasRequestedLoad = true
                    Task { await contentViewModel.loadShowsForCategory(category) }
                    #endif
                }
            } else {
                ForEach(shows.prefix(PlatformMetrics.posterRowItemLimit)) { show in
                    ShowCard(show: show) {
                        onSelectShow(show)
                    } onLongPress: {
                        onToggleFavorite(show)
                    }
                    .frame(width: PlatformMetrics.posterCardWidth)
                }
                
                if shows.count > PlatformMetrics.posterRowItemLimit {
                    SeeAllButton(height: PlatformMetrics.posterCardWidth * 1.5) { onSeeAll() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ShowsView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
