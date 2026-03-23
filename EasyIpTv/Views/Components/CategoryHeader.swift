import SwiftUI

/// Header view for content categories -- Liquid Glass style
struct CategoryHeader: View {
    let title: String
    let icon: String?
    let itemCount: Int?
    var showSeeAll: Bool = false
    var onSeeAll: (() -> Void)? = nil
    var showFavoriteButton: Bool = false
    var isFavorited: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var scheme
    @FocusState private var isFocused: Bool
    
    init(
        title: String,
        icon: String? = nil,
        itemCount: Int? = nil,
        showSeeAll: Bool = false,
        onSeeAll: (() -> Void)? = nil,
        showFavoriteButton: Bool = false,
        isFavorited: Bool = false,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.itemCount = itemCount
        self.showSeeAll = showSeeAll
        self.onSeeAll = onSeeAll
        self.showFavoriteButton = showFavoriteButton
        self.isFavorited = isFavorited
        self.onToggleFavorite = onToggleFavorite
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if showFavoriteButton, let onToggleFavorite = onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    HStack(spacing: 10) {
                        titleContent
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isFavorited ? AppTheme.tertiary : AppTheme.onSurfaceVariant(scheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    #if os(tvOS)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isFocused ? Color.white.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFocused ? AppTheme.primary.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
                    #endif
                }
                .buttonStyle(.plain)
                .focused($isFocused)
                #if os(tvOS)
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                #endif
            } else {
                titleContent
            }
            
            Spacer()
            
            if showSeeAll, let onSeeAll = onSeeAll {
                Button {
                    onSeeAll()
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.Content.seeAll)
                            .font(AppTypography.label)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }
        }
        #if os(tvOS)
        .padding(.horizontal, 50)
        #else
        .padding(.horizontal)
        #endif
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var titleContent: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
            }
            
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppTheme.onSurface(scheme))
            
            if let count = itemCount {
                Text("\(count)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.surfaceContainerHigh(scheme), in: Capsule())
            }
        }
    }
}

// MARK: - Category Row

/// Horizontal scrolling row of content with a category header
struct CategoryRow<Content: View>: View {
    let title: String
    let icon: String?
    let itemCount: Int?
    let content: () -> Content
    var showFavoriteButton: Bool = false
    var isFavorited: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    
    init(
        title: String,
        icon: String? = nil,
        itemCount: Int? = nil,
        showFavoriteButton: Bool = false,
        isFavorited: Bool = false,
        onToggleFavorite: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.itemCount = itemCount
        self.showFavoriteButton = showFavoriteButton
        self.isFavorited = isFavorited
        self.onToggleFavorite = onToggleFavorite
        self.content = content
    }
    
    private var rowHorizontalPadding: CGFloat {
        #if os(tvOS)
        return 50
        #else
        return 16
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CategoryHeader(
                title: title,
                icon: icon,
                itemCount: itemCount,
                showFavoriteButton: showFavoriteButton,
                isFavorited: isFavorited,
                onToggleFavorite: onToggleFavorite
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PlatformMetrics.horizontalSpacing) {
                    content()
                }
                .padding(.horizontal, rowHorizontalPadding)
            }
            .platformFocusSection()
        }
    }
}

// MARK: - Category Grid

/// Grid layout for content within a category
struct CategoryGrid<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let columns: Int
    let minItemWidth: CGFloat
    let itemView: (Item) -> ItemView
    
    init(
        items: [Item],
        columns: Int = PlatformMetrics.gridColumns,
        minItemWidth: CGFloat = PlatformMetrics.posterCardWidth,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.minItemWidth = minItemWidth
        self.itemView = itemView
    }
    
    private var gridColumns: [GridItem] {
        #if os(macOS)
        return [GridItem(.adaptive(minimum: minItemWidth, maximum: minItemWidth * 2), spacing: PlatformMetrics.horizontalSpacing)]
        #else
        return Array(repeating: GridItem(.flexible(), spacing: PlatformMetrics.horizontalSpacing), count: columns)
        #endif
    }
    
    var body: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: PlatformMetrics.horizontalSpacing
        ) {
            ForEach(items) { item in
                itemView(item)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Hero Banner

/// Featured content hero banner with auto-advancement -- Liquid Glass style
struct HeroBanner<Item: Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    let subtitle: (Item) -> String?
    let imageURL: (Item) -> URL?
    var onSelect: (Item) -> Void = { _ in }
    
    @Environment(\.colorScheme) private var scheme
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !items.isEmpty {
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(url: imageURL(items[currentIndex])) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ShimmerPlaceholder()
                    }
                    .frame(height: PlatformMetrics.heroBannerHeight)
                    .clipped()
                    
                    LinearGradient(
                        colors: [
                            AppTheme.background(scheme),
                            AppTheme.background(scheme).opacity(0.7),
                            AppTheme.background(scheme).opacity(0.2),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.Content.featured.uppercased())
                            .font(AppTypography.label)
                            .tracking(1.5)
                            .foregroundColor(AppTheme.primary)
                        
                        Text(title(items[currentIndex]))
                            .font(AppTypography.heroTitle)
                            .foregroundColor(AppTheme.onSurface(scheme))
                        
                        if let sub = subtitle(items[currentIndex]) {
                            Text(sub)
                                .font(AppTypography.bodyLarge)
                                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 16) {
                            Button {
                                onSelect(items[currentIndex])
                            } label: {
                                Label(L10n.Player.play, systemImage: "play.fill")
                            }
                            .buttonStyle(PrimaryPillButtonStyle())
                            
                            HStack(spacing: 6) {
                                ForEach(0..<min(items.count, 5), id: \.self) { index in
                                    Capsule()
                                        .fill(index == currentIndex ? AppTheme.primary : AppTheme.onSurface(scheme).opacity(0.25))
                                        .frame(width: index == currentIndex ? 20 : 6, height: 6)
                                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(PlatformMetrics.detailPadding)
                }
                .focused($isFocused)
                #if os(tvOS)
                .onMoveCommand { direction in
                    switch direction {
                    case .left: previousItem()
                    case .right: nextItem()
                    default: break
                    }
                }
                #endif
            }
        }
        .onAppear { startAutoAdvance() }
        .onDisappear { stopAutoAdvance() }
        .onChange(of: isFocused) { _, focused in
            if focused { stopAutoAdvance() } else { startAutoAdvance() }
        }
    }
    
    private func startAutoAdvance() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            nextItem()
        }
    }
    
    private func stopAutoAdvance() {
        timer?.invalidate()
        timer = nil
    }
    
    private func nextItem() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentIndex = (currentIndex + 1) % min(items.count, 5)
        }
    }
    
    private func previousItem() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentIndex = currentIndex == 0 ? min(items.count - 1, 4) : currentIndex - 1
        }
    }
}

// MARK: - Skeleton Loading Views

struct SkeletonCard: View {
    let aspectRatio: CGFloat
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShimmerPlaceholder()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .cornerRadius(PlatformMetrics.cardCornerRadius)
            
            ShimmerPlaceholder()
                .frame(height: 14)
                .frame(maxWidth: .infinity)
                .cornerRadius(4)
            
            ShimmerPlaceholder()
                .frame(height: 10)
                .frame(width: 100)
                .cornerRadius(4)
        }
    }
}

struct SkeletonRow: View {
    let cardCount: Int
    let aspectRatio: CGFloat
    let cardWidth: CGFloat
    
    init(cardCount: Int = 5, aspectRatio: CGFloat = 16/9, cardWidth: CGFloat = 0) {
        self.cardCount = cardCount
        self.aspectRatio = aspectRatio
        self.cardWidth = cardWidth > 0 ? cardWidth : PlatformMetrics.channelCardWidth
    }
    
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ShimmerPlaceholder()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
                
                ShimmerPlaceholder()
                    .frame(width: 200, height: 18)
                    .cornerRadius(6)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PlatformMetrics.horizontalSpacing) {
                    ForEach(0..<cardCount, id: \.self) { _ in
                        SkeletonCard(aspectRatio: aspectRatio)
                            .frame(width: cardWidth)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SkeletonPageView: View {
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: PlatformMetrics.sectionSpacing) {
                ShimmerPlaceholder()
                    .frame(height: PlatformMetrics.heroBannerHeight - 100)
                
                SkeletonRow(cardCount: 5, aspectRatio: 16/9, cardWidth: PlatformMetrics.channelCardWidth)
                SkeletonRow(cardCount: 6, aspectRatio: 2/3, cardWidth: PlatformMetrics.posterCardWidth)
                SkeletonRow(cardCount: 6, aspectRatio: 2/3, cardWidth: PlatformMetrics.posterCardWidth)
            }
        }
        .background(AppTheme.background(scheme))
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 30) {
        CategoryHeader(
            title: "Hungarian Channels",
            icon: "tv",
            itemCount: 42,
            showSeeAll: true
        ) {
            #if DEBUG
            print("See all tapped")
            #endif
        }
        
        CategoryHeader(
            title: "Action Movies",
            itemCount: 156
        )
        
        SkeletonRow()
    }
    .padding()
}
