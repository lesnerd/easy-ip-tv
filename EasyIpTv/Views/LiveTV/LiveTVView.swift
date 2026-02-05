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
    
    @State private var selectedCategory: ContentViewModel.CategoryInfo?
    @State private var selectedChannel: Channel?
    @State private var showPlayer = false
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
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let channel = selectedChannel {
                PlayerView(channel: channel)
            }
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
            VStack(alignment: .leading, spacing: 30) {
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
                    CategoryGrid(items: filteredChannels, columns: 5) { channel in
                        ChannelCard(channel: channel) {
                            playChannel(channel)
                        } onLongPress: {
                            toggleFavorite(channel)
                        }
                    }
                }
            }
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Category List View
    
    private var categoryListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                // Featured channels row (only in "all" mode)
                if filterMode == .all && !contentViewModel.featuredChannels.isEmpty {
                    CategoryRow(
                        title: L10n.Content.featured,
                        icon: "star.fill",
                        itemCount: contentViewModel.featuredChannels.count
                    ) {
                        ForEach(contentViewModel.featuredChannels.prefix(10)) { channel in
                            ChannelCard(channel: channel) {
                                playChannel(channel)
                            } onLongPress: {
                                toggleFavorite(channel)
                            }
                            .frame(width: 300)
                        }
                    }
                }
                
                // Category rows based on filter - tap to load
                ForEach(filteredCategories) { category in
                    let channels = contentViewModel.channels(in: category.name)
                    let allFavorites = contentViewModel.isCategoryAllFavorites(category)
                    
                    CategoryRow(
                        title: category.name,
                        itemCount: category.itemCount ?? channels.count,
                        showFavoriteButton: !channels.isEmpty,
                        isFavorited: allFavorites,
                        onToggleFavorite: {
                            if allFavorites {
                                contentViewModel.removeCategoryFromFavorites(category)
                            } else {
                                contentViewModel.addCategoryToFavorites(category)
                            }
                        }
                    ) {
                        if channels.isEmpty {
                            // Show loading placeholder or tap to load
                            Button {
                                Task {
                                    await contentViewModel.loadChannelsForCategory(category)
                                }
                            } label: {
                                VStack {
                                    if contentViewModel.isLoadingCategory {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.largeTitle)
                                        Text("Load Channels")
                                            .font(.callout)
                                    }
                                }
                                .frame(width: 200, height: 150)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            }
                            .buttonStyle(CardButtonStyle())
                        } else {
                            ForEach(channels.prefix(10)) { channel in
                                ChannelCard(channel: channel) {
                                    playChannel(channel)
                                } onLongPress: {
                                    toggleFavorite(channel)
                                }
                                .frame(width: 300)
                            }
                            
                            // See more button
                            if channels.count > 10 {
                                Button {
                                    selectedCategory = category
                                } label: {
                                    VStack {
                                        Image(systemName: "ellipsis")
                                            .font(.largeTitle)
                                        Text("See All")
                                            .font(.callout)
                                    }
                                    .frame(width: 150, height: 169)
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
        let channels = contentViewModel.channels(in: category.name)
        let allFavorites = contentViewModel.isCategoryAllFavorites(category)
        
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
                
                // Category header with favorite button
                CategoryHeader(
                    title: category.name,
                    icon: "tv",
                    itemCount: channels.count,
                    showFavoriteButton: !channels.isEmpty,
                    isFavorited: allFavorites,
                    onToggleFavorite: {
                        if allFavorites {
                            contentViewModel.removeCategoryFromFavorites(category)
                        } else {
                            contentViewModel.addCategoryToFavorites(category)
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
                    CategoryGrid(items: channels, columns: 5) { channel in
                        ChannelCard(channel: channel) {
                            playChannel(channel)
                        } onLongPress: {
                            toggleFavorite(channel)
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
            icon: "tv.slash",
            title: L10n.Errors.noPlaylist,
            message: L10n.Errors.noPlaylistDescription
        )
    }
    
    // MARK: - Actions
    
    private func playChannel(_ channel: Channel) {
        selectedChannel = channel
        showPlayer = true
    }
    
    private func toggleFavorite(_ channel: Channel) {
        contentViewModel.toggleFavorite(channel: channel)
        favoritesViewModel.toggleFavorite(channel: channel)
    }
}

// MARK: - Preview

#Preview {
    LiveTVView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
