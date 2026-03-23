import SwiftUI

/// Filter mode for Live TV -- dynamically built from user's language priorities
struct ChannelFilterMode: Equatable, Hashable {
    let id: String
    let title: String
    let icon: String
    
    static let all = ChannelFilterMode(id: "all", title: "All", icon: "tv")
    static let other = ChannelFilterMode(id: "other", title: "Other", icon: "globe")
    
    static func fromPriorities(_ config: LanguagePriorityConfig, categories: [ContentViewModel.CategoryInfo] = []) -> [ChannelFilterMode] {
        var modes: [ChannelFilterMode] = [.all]
        
        if !config.preferred.isEmpty {
            for langId in config.preferred {
                if let lang = IPTVLanguage.byId[langId] {
                    modes.append(ChannelFilterMode(id: lang.id, title: lang.displayName, icon: "flag"))
                }
            }
        } else if !categories.isEmpty {
            var seen = Set<String>()
            for cat in categories {
                if let lang = IPTVLanguage.detect(from: cat.name), !seen.contains(lang.id) {
                    seen.insert(lang.id)
                    modes.append(ChannelFilterMode(id: lang.id, title: lang.displayName, icon: "flag"))
                }
            }
        }
        
        modes.append(.other)
        return modes
    }
}

/// Main Live TV view -- Liquid Glass redesign
struct LiveTVView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var premiumManager: PremiumManager
    @ObservedObject var epgService = EPGService.shared
    @Environment(\.colorScheme) private var scheme
    
    @State private var selectedCategory: ContentViewModel.CategoryInfo?
    @State private var selectedChannel: Channel?
    @State private var playingChannel: Channel?
    @State private var showUpgrade = false
    @State private var showInterstitial = false
    @State private var searchText = ""
    @State private var filterMode: ChannelFilterMode = .all
    @State private var showSearchResults = false
    @State private var showEPGGuide = false
    @State private var catchupChannel: Channel?
    
    private var filterModes: [ChannelFilterMode] {
        ChannelFilterMode.fromPriorities(
            contentViewModel.languagePriorityConfig,
            categories: contentViewModel.liveCategories
        )
    }
    
    private var filteredChannels: [Channel] {
        let baseChannels: [Channel]
        if filterMode == .all {
            baseChannels = contentViewModel.allLoadedChannels
        } else {
            let categoryNames = Set(filteredCategories.map(\.name))
            baseChannels = contentViewModel.allLoadedChannels.filter { categoryNames.contains($0.category) }
        }
        guard !searchText.isEmpty else { return baseChannels }
        return baseChannels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredCategories: [ContentViewModel.CategoryInfo] {
        if filterMode == .all {
            return contentViewModel.liveCategories
        } else if filterMode == .other {
            return contentViewModel.uncategorizedLanguageCategories
        } else {
            return contentViewModel.categories(for: filterMode.id)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGradientBackground(intensity: 0.25)
                    .ignoresSafeArea()
                
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
            }
            #if !os(tvOS)
            .navigationTitle(L10n.Navigation.liveTV)
            #endif
            .searchable(text: $searchText, prompt: L10n.Actions.search)
            .onChange(of: searchText) { _, newValue in
                showSearchResults = !newValue.isEmpty
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showEPGGuide = true
                    } label: {
                        Label("TV Guide", systemImage: "list.bullet.rectangle.fill")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    filterMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                BannerAdView { showUpgrade = true }
                    .environmentObject(premiumManager)
            }
        }
        .platformFullScreen(item: $playingChannel) { channel in
            PlayerView(channel: channel, onClose: {
                NSLog("[LiveTV] Player closed for channel %@", channel.name)
                playingChannel = nil
            })
                .id(channel.id)
                .environmentObject(contentViewModel)
        }
        .overlay {
            if showInterstitial {
                InterstitialAdOverlay(
                    onDismiss: {
                        showInterstitial = false
                        playingChannel = selectedChannel
                    },
                    onUpgrade: {
                        showInterstitial = false
                        showUpgrade = true
                    }
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
        .sheet(isPresented: $showEPGGuide) {
            EPGGuideView(
                channels: contentViewModel.channels,
                onPlayChannel: { channel in
                    showEPGGuide = false
                    playChannel(channel)
                },
                onPlayCatchup: { channel, program in
                    showEPGGuide = false
                    playCatchup(channel: channel, program: program)
                }
            )
        }
        .sheet(item: $catchupChannel) { channel in
            CatchupView(channel: channel) { ch, program in
                playCatchup(channel: ch, program: program)
            }
        }
    }
    
    // MARK: - Filter Pills
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterModes, id: \.id) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filterMode = mode
                        }
                    } label: {
                        Text(mode.title)
                            .font(AppTypography.label)
                            .foregroundColor(
                                filterMode == mode
                                    ? AppTheme.onPrimaryContainer
                                    : AppTheme.onSurfaceVariant(scheme)
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                filterMode == mode
                                    ? AppTheme.primary
                                    : AppTheme.surfaceContainerHigh(scheme),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        filterMode == mode
                                            ? Color.clear
                                            : AppTheme.glassBorder(scheme),
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 50)
            #else
            .padding(.horizontal)
            #endif
        }
    }
    
    // MARK: - Filter Menu (toolbar fallback)
    
    private var filterMenu: some View {
        Menu {
            ForEach(filterModes, id: \.id) { mode in
                Button {
                    filterMode = mode
                } label: {
                    Label(mode.title, systemImage: mode.icon)
                    if filterMode == mode {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filterMode.icon)
                Text(filterMode.title)
                    .font(AppTypography.label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(AppTheme.onSurface(scheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surfaceContainerHigh(scheme), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.glassBorder(scheme), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Search Results View
    
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    searchText = ""
                    showSearchResults = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.Content.categories)
                            .font(AppTypography.bodyMedium)
                    }
                    .foregroundColor(AppTheme.primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
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
                    CategoryGrid(items: filteredChannels, columns: PlatformMetrics.gridColumns, minItemWidth: PlatformMetrics.channelCardWidth) { channel in
                        ChannelCard(channel: channel, nowPlaying: nowPlayingText(for: channel), onTap: {
                            playChannel(channel)
                        }, onLongPress: {
                            toggleFavorite(channel)
                        }, onCatchup: channel.hasCatchup ? { catchupChannel = channel } : nil)
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
                filterPills
                    .padding(.top, 4)
                
                if filterMode == .all && !contentViewModel.featuredChannels.isEmpty {
                    featuredSection
                }
                
                ForEach(filteredCategories) { category in
                    LiveCategoryRowView(
                        category: category,
                        onPlayChannel: { playChannel($0) },
                        onToggleFavorite: { toggleFavorite($0) },
                        onCatchupChannel: { catchupChannel = $0 },
                        onSeeAll: { selectedCategory = category }
                    )
                    .environmentObject(contentViewModel)
                    .environmentObject(favoritesViewModel)
                }
            }
            .padding(.vertical, PlatformMetrics.contentPadding)
        }
    }
    
    // MARK: - Featured Section
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CategoryHeader(
                title: L10n.Content.featured,
                icon: "star.fill",
                itemCount: contentViewModel.featuredChannels.count
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(contentViewModel.featuredChannels.prefix(PlatformMetrics.rowItemLimit)) { channel in
                        FeaturedChannelCard(
                            channel: channel,
                            nowPlaying: nowPlayingText(for: channel),
                            onTap: { playChannel(channel) }
                        )
                    }
                }
                #if os(tvOS)
                .padding(.horizontal, 50)
                #else
                .padding(.horizontal)
                #endif
            }
            .platformFocusSection()
        }
    }
    
    // MARK: - Category Detail View
    
    private func categoryDetailView(category: ContentViewModel.CategoryInfo) -> some View {
        let allChannels = contentViewModel.channels(in: category.name)
        let channels = searchText.isEmpty ? allChannels : allChannels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        let allFavorites = contentViewModel.isCategoryAllFavorites(category)
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    selectedCategory = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.Content.categories)
                            .font(AppTypography.bodyMedium)
                    }
                    .foregroundColor(AppTheme.primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
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
                
                if contentViewModel.loadingCategoryIds.contains(category.id) {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else if allChannels.isEmpty && !contentViewModel.isCategoryLoaded(category.name) {
                    Color.clear.onAppear {
                        Task { await contentViewModel.loadChannelsForCategory(category) }
                    }
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 100)
                } else if allChannels.isEmpty {
                    EmptyStateView(
                        icon: "tv",
                        title: "No Channels",
                        message: "No channels available in \(category.name)"
                    )
                } else if channels.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No channels found matching \"\(searchText)\" in \(category.name)"
                    )
                } else {
                    CategoryGrid(items: channels, columns: PlatformMetrics.gridColumns, minItemWidth: PlatformMetrics.channelCardWidth) { channel in
                        ChannelCard(channel: channel, nowPlaying: nowPlayingText(for: channel), onTap: {
                            playChannel(channel)
                        }, onLongPress: {
                            toggleFavorite(channel)
                        }, onCatchup: channel.hasCatchup ? { catchupChannel = channel } : nil)
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
        guard playingChannel == nil else { return }
        selectedChannel = channel
        AdManager.shared.recordPlay()
        if AdManager.shared.showInterstitialIfNeeded(premiumManager: premiumManager) {
            showInterstitial = true
        } else {
            playingChannel = channel
        }
    }
    
    private func toggleFavorite(_ channel: Channel) {
        contentViewModel.toggleFavorite(channel: channel)
        favoritesViewModel.toggleFavorite(channel: channel)
    }
    
    private func playCatchup(channel: Channel, program: EPGProgram) {
        guard let archiveURL = contentViewModel.buildArchiveURL(for: channel, program: program) else { return }
        let archiveChannel = Channel(
            id: channel.id,
            name: "\(channel.name) - \(program.title)",
            logoURL: channel.logoURL,
            streamURL: archiveURL,
            category: channel.category,
            streamId: channel.streamId
        )
        playingChannel = archiveChannel
    }
    
    private func nowPlayingText(for channel: Channel) -> String? {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        guard let key else { return nil }
        return epgService.nowPlaying(for: key)?.title
    }
}

// MARK: - Featured Channel Card (large hero-style card)

struct FeaturedChannelCard: View {
    let channel: Channel
    var nowPlaying: String? = nil
    var onTap: () -> Void = {}
    
    @Environment(\.colorScheme) private var scheme
    @State private var isHovered = false
    @ObservedObject private var epgService = EPGService.shared
    
    private var cardWidth: CGFloat {
        #if os(tvOS)
        return 420
        #elseif os(macOS)
        return 360
        #else
        return 300
        #endif
    }
    
    private var currentProgram: EPGProgram? {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        guard let key else { return nil }
        return epgService.nowPlaying(for: key)
    }
    
    var body: some View {
        Button { onTap() } label: {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: channel.logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.primary.opacity(0.2),
                                    AppTheme.secondary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Text(channel.name.prefix(3).uppercased())
                                #if os(tvOS)
                                .font(.system(size: 40, weight: .black))
                                #else
                                .font(.system(size: 24, weight: .black))
                                #endif
                                .foregroundColor(.white.opacity(0.12))
                        }
                }
                .frame(width: cardWidth, height: cardWidth * 9 / 16)
                .clipped()
                
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        Color.black.opacity(0.4),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        LiveBadge()
                        if channel.hasCatchup {
                            Text("Catchup")
                                .font(AppTypography.micro)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.catchupBadge.opacity(0.85), in: Capsule())
                        }
                    }
                    
                    Text(channel.name)
                        #if os(tvOS)
                        .font(.system(size: 22, weight: .bold))
                        #else
                        .font(AppTypography.sectionTitle)
                        #endif
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let program = currentProgram {
                        Text(program.title)
                            #if os(tvOS)
                            .font(.system(size: 16))
                            #else
                            .font(AppTypography.bodyMedium)
                            #endif
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                        
                        GlowProgressBar(
                            progress: program.progress,
                            height: 3,
                            trackColor: Color.white.opacity(0.15),
                            barColor: AppTheme.primary
                        )
                        .padding(.top, 2)
                    } else if let nowPlaying {
                        Text(nowPlaying)
                            #if os(tvOS)
                            .font(.system(size: 16))
                            #else
                            .font(AppTypography.bodyMedium)
                            #endif
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(16)
            }
            .frame(width: cardWidth, height: cardWidth * 9 / 16)
            .background(Color(hex: 0x1A1A1E))
            .cornerRadius(PlatformMetrics.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: PlatformMetrics.cardCornerRadius)
                    .stroke(AppTheme.glassBorder(scheme), lineWidth: 0.5)
            )
            #if !os(tvOS)
            .shadow(
                color: isHovered ? AppTheme.primary.opacity(0.30) : Color.black.opacity(0.2),
                radius: isHovered ? 20 : 8,
                y: isHovered ? 6 : 3
            )
            #endif
        }
        .buttonStyle(CardButtonStyle())
        .tvOSFocusEffectDisabled()
        #if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering }
        }
        #endif
    }
}

// MARK: - Live Category Row View

private struct LiveCategoryRowView: View {
    let category: ContentViewModel.CategoryInfo
    var onPlayChannel: (Channel) -> Void
    var onToggleFavorite: (Channel) -> Void
    var onCatchupChannel: ((Channel) -> Void)? = nil
    var onSeeAll: () -> Void
    
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @ObservedObject private var epgService = EPGService.shared
    @Environment(\.colorScheme) private var scheme
    @State private var hasRequestedLoad = false
    
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
            if channels.isEmpty && category.itemCount == 0 {
                Text("No channels available")
                    .font(AppTypography.caption)
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            } else if channels.isEmpty && !contentViewModel.isCategoryLoaded(category.name) && !hasRequestedLoad {
                CategoryLoadingPlaceholder(isLoading: isLoading, label: "Load Channels") {
                    Task { await contentViewModel.loadChannelsForCategory(category) }
                }
                .onAppear {
                    hasRequestedLoad = true
                    Task { await contentViewModel.loadChannelsForCategory(category) }
                    contentViewModel.prefetchNearbyCategories(around: category, in: contentViewModel.liveCategories, contentType: "channels")
                }
            } else if channels.isEmpty && isLoading {
                CategoryLoadingPlaceholder(isLoading: true, label: "Loading...") {}
            } else if channels.isEmpty {
                Text("No channels available")
                    .font(AppTypography.caption)
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(channels.prefix(PlatformMetrics.rowItemLimit)) { channel in
                    ChannelCard(
                        channel: channel,
                        nowPlaying: nowPlayingText(for: channel),
                        onTap: { onPlayChannel(channel) },
                        onLongPress: { onToggleFavorite(channel) },
                        onCatchup: channel.hasCatchup ? { onCatchupChannel?(channel) } : nil
                    )
                    .frame(width: PlatformMetrics.channelCardWidth)
                }
                
                if channels.count > PlatformMetrics.rowItemLimit {
                    SeeAllButton(height: 169) { onSeeAll() }
                }
            }
        }
    }
    
    private func nowPlayingText(for channel: Channel) -> String? {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        guard let key else { return nil }
        return epgService.nowPlaying(for: key)?.title
    }
}

// MARK: - Reusable Components

struct CategoryLoadingPlaceholder: View {
    let isLoading: Bool
    let label: String
    var onTap: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        #if os(tvOS)
        Button {
            onTap()
        } label: {
            placeholderContent
        }
        .buttonStyle(CardButtonStyle())
        .tvOSFocusEffectDisabled()
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

struct SeeAllButton: View {
    var height: CGFloat = 169
    var onTap: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                Text(L10n.Content.seeAll)
                    .font(AppTypography.label)
            }
            .foregroundColor(AppTheme.onSurfaceVariant(scheme))
            .frame(width: 120, height: height)
            .background(AppTheme.surfaceContainerHigh(scheme))
            .cornerRadius(PlatformMetrics.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: PlatformMetrics.cardCornerRadius)
                    .stroke(AppTheme.glassBorder(scheme), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardButtonStyle())
        .tvOSFocusEffectDisabled()
    }
}

// MARK: - Preview

#Preview {
    LiveTVView()
        .environmentObject(ContentViewModel())
        .environmentObject(FavoritesViewModel())
}
