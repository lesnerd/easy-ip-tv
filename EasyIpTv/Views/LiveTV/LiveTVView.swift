import SwiftUI

/// Filter mode for Live TV
enum ChannelFilterMode: String, CaseIterable {
    case all = "All"
    case hungarian = "Hungarian"
    case israeli = "Israeli"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .all: return "tv"
        case .hungarian: return "flag"
        case .israeli: return "flag.fill"
        case .other: return "globe"
        }
    }
}

/// Main Live TV view with category navigation and lazy loading
struct LiveTVView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var selectedCategory: ContentViewModel.CategoryInfo?
    @State private var selectedChannel: Channel?
    @State private var showPlayer = false
    @State private var showUpgrade = false
    @State private var showInterstitial = false
    @State private var searchText = ""
    @State private var filterMode: ChannelFilterMode = .all
    @State private var showSearchResults = false
    
    private var filteredChannels: [Channel] {
        var channels = contentViewModel.channels
        
        // Apply search filter
        if !searchText.isEmpty {
            channels = channels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return channels
    }
    
    private var filteredCategories: [ContentViewModel.CategoryInfo] {
        switch filterMode {
        case .all:
            return contentViewModel.liveCategories
        case .hungarian:
            return contentViewModel.hungarianCategories
        case .israeli:
            return contentViewModel.israeliCategories
        case .other:
            return contentViewModel.otherCategories
        }
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
                } else if showSearchResults && !searchText.isEmpty {
                    searchResultsView
                } else {
                    categoryListView
                }
            }
            .navigationTitle(L10n.Navigation.liveTV)
            .searchable(text: $searchText, prompt: L10n.Actions.search)
            .onChange(of: searchText) { _, newValue in
                showSearchResults = !newValue.isEmpty
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    filterMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                BannerAdView { showUpgrade = true }
                    .environmentObject(premiumManager)
            }
        }
        .platformFullScreen(isPresented: $showPlayer) {
            if let channel = selectedChannel {
                PlayerView(channel: channel)
            }
        }
        .platformFullScreen(isPresented: $showInterstitial) {
            InterstitialAdOverlay(
                onDismiss: {
                    showInterstitial = false
                    showPlayer = true
                },
                onUpgrade: {
                    showInterstitial = false
                    showUpgrade = true
                }
            )
            .environmentObject(premiumManager)
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradePromptView()
                .environmentObject(premiumManager)
        }
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            ForEach(ChannelFilterMode.allCases, id: \.self) { mode in
                Button {
                    filterMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                    if filterMode == mode {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filterMode.icon)
                Text(filterMode.rawValue)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Search Results View
    
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Back button
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
                
                // Results header
                CategoryHeader(
                    title: "\(L10n.Actions.search): \"\(searchText)\"",
                    icon: "magnifyingglass",
                    itemCount: filteredChannels.count
                )
                
                if filteredChannels.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No channels found matching \"\(searchText)\""
                    )
                } else {
                    // Channel grid
                    CategoryGrid(items: filteredChannels, columns: PlatformMetrics.gridColumns) { channel in
                        ChannelCard(channel: channel) {
                            playChannel(channel)
                        } onLongPress: {
                            toggleFavorite(channel)
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
                // Featured channels row (only in "all" mode)
                if filterMode == .all && !contentViewModel.featuredChannels.isEmpty {
                    CategoryRow(
                        title: L10n.Content.featured,
                        icon: "star.fill",
                        itemCount: contentViewModel.featuredChannels.count
                    ) {
                        ForEach(contentViewModel.featuredChannels.prefix(PlatformMetrics.rowItemLimit)) { channel in
                            ChannelCard(channel: channel) {
                                playChannel(channel)
                            } onLongPress: {
                                toggleFavorite(channel)
                            }
                            .frame(width: PlatformMetrics.channelCardWidth)
                        }
                    }
                }
                
                // Category rows - auto-load on appear (macOS/iOS) or tap to load (tvOS)
                ForEach(filteredCategories) { category in
                    LiveCategoryRowView(
                        category: category,
                        onPlayChannel: { playChannel($0) },
                        onToggleFavorite: { toggleFavorite($0) },
                        onSeeAll: { selectedCategory = category }
                    )
                    .environmentObject(contentViewModel)
                    .environmentObject(favoritesViewModel)
                }
            }
            .padding(.vertical, PlatformMetrics.contentPadding)
        }
    }
    
    // MARK: - Category Detail View
    
    private func categoryDetailView(category: ContentViewModel.CategoryInfo) -> some View {
        let channels = contentViewModel.channels(in: category.name)
        let allFavorites = contentViewModel.isCategoryAllFavorites(category)
        
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
                
                // Category header with favorite button
                CategoryHeader(
                    title: category.name,
                    icon: "tv",
                    itemCount: channels.count,
                    showFavoriteButton: !channels.isEmpty,
                    isFavorited: allFavorites,
                    onToggleFavorite: {
                        let currentChannels = contentViewModel.channels(in: category.name)
                        let isCurrentlyAllFavorites = contentViewModel.isCategoryAllFavorites(category)
                        
                        if isCurrentlyAllFavorites {
                            contentViewModel.removeCategoryFromFavorites(category)
                            favoritesViewModel.removeFavorites(channels: currentChannels)
                        } else {
                            contentViewModel.addCategoryToFavorites(category)
                            favoritesViewModel.addFavorites(channels: currentChannels)
                        }
                    }
                )
                
                if contentViewModel.isLoadingCategory {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else if channels.isEmpty {
                    // Auto-load when navigating to detail
                    Color.clear.onAppear {
                        Task {
                            await contentViewModel.loadChannelsForCategory(category)
                        }
                    }
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else {
                    // Channel grid
                    CategoryGrid(items: channels, columns: PlatformMetrics.gridColumns) { channel in
                        ChannelCard(channel: channel) {
                            playChannel(channel)
                        } onLongPress: {
                            toggleFavorite(channel)
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
            icon: "tv.slash",
            title: L10n.Errors.noPlaylist,
            message: L10n.Errors.noPlaylistDescription
        )
    }
    
    // MARK: - Actions
    
    private func playChannel(_ channel: Channel) {
        selectedChannel = channel
        AdManager.shared.recordPlay()
        if AdManager.shared.showInterstitialIfNeeded(premiumManager: premiumManager) {
            showInterstitial = true
        } else {
            showPlayer = true
        }
    }
    
    private func toggleFavorite(_ channel: Channel) {
        contentViewModel.toggleFavorite(channel: channel)
        favoritesViewModel.toggleFavorite(channel: channel)
    }
}

// MARK: - Live Category Row View (handles auto-loading)

/// A category row that auto-loads its content when it appears on screen
private struct LiveCategoryRowView: View {
    let category: ContentViewModel.CategoryInfo
    var onPlayChannel: (Channel) -> Void
    var onToggleFavorite: (Channel) -> Void
    var onSeeAll: () -> Void
    
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    var body: some View {
        let channels = contentViewModel.channels(in: category.name)
        let allFavorites = contentViewModel.isCategoryAllFavorites(category)
        let isLoading = contentViewModel.isCategoryLoading(category)
        
        CategoryRow(
            title: category.name,
            itemCount: category.itemCount ?? channels.count,
            showFavoriteButton: !channels.isEmpty,
            isFavorited: allFavorites,
            onToggleFavorite: {
                let currentChannels = contentViewModel.channels(in: category.name)
                let isCurrentlyAllFavorites = contentViewModel.isCategoryAllFavorites(category)
                
                if isCurrentlyAllFavorites {
                    contentViewModel.removeCategoryFromFavorites(category)
                    favoritesViewModel.removeFavorites(channels: currentChannels)
                } else {
                    contentViewModel.addCategoryToFavorites(category)
                    favoritesViewModel.addFavorites(channels: currentChannels)
                }
            }
        ) {
            if channels.isEmpty {
                // Loading placeholder
                CategoryLoadingPlaceholder(isLoading: isLoading, label: "Load Channels") {
                    Task { await contentViewModel.loadChannelsForCategory(category) }
                }
                .onAppear {
                    #if !os(tvOS)
                    // Auto-load when visible on macOS/iOS
                    Task { await contentViewModel.loadChannelsForCategory(category) }
                    #endif
                }
            } else {
                ForEach(channels.prefix(PlatformMetrics.rowItemLimit)) { channel in
                    ChannelCard(channel: channel) {
                        onPlayChannel(channel)
                    } onLongPress: {
                        onToggleFavorite(channel)
                    }
                    .frame(width: PlatformMetrics.channelCardWidth)
                }
                
                if channels.count > PlatformMetrics.rowItemLimit {
                    SeeAllButton(height: 169) { onSeeAll() }
                }
            }
        }
    }
}

// MARK: - Reusable Loading / See All Components

/// Placeholder shown while a category is loading
struct CategoryLoadingPlaceholder: View {
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
                SkeletonCard(aspectRatio: 16/9)
                    .frame(width: PlatformMetrics.channelCardWidth)
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

/// "See All" button at the end of a row
struct SeeAllButton: View {
    var height: CGFloat = 169
    var onTap: () -> Void = {}
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                Text(L10n.Content.seeAll)
                    .font(.callout)
            }
            .foregroundStyle(.secondary)
            .frame(width: 120, height: height)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    LiveTVView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
