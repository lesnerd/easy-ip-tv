import SwiftUI

/// Header view for content categories
struct CategoryHeader: View {
    let title: String
    let icon: String?
    let itemCount: Int?
    var showSeeAll: Bool = false
    var onSeeAll: (() -> Void)? = nil
    
    // Favorite functionality
    var showFavoriteButton: Bool = false
    var isFavorited: Bool = false
    var onToggleFavorite: (() -> Void)? = nil
    
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
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Make the title + heart a single focusable button
            if showFavoriteButton, let onToggleFavorite = onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    HStack(spacing: 12) {
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(title)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if let count = itemCount {
                            Text("(\(count))")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundColor(isFavorited ? .red : .secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    #if os(tvOS)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isFocused ? Color.white.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isFocused ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
                    #else
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.clear)
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
                // Non-clickable header (no favorite button)
                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if let count = itemCount {
                        Text("(\(count))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if showSeeAll, let onSeeAll = onSeeAll {
                Button {
                    onSeeAll()
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.Content.seeAll)
                            .font(.callout)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Category Row

/// Horizontal scrolling row of content with a category header
struct CategoryRow<Content: View>: View {
    let title: String
    let icon: String?
    let itemCount: Int?
    let content: () -> Content
    
    // Favorite functionality
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
                .padding(.horizontal)
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
    let itemView: (Item) -> ItemView
    
    init(
        items: [Item],
        columns: Int = PlatformMetrics.gridColumns,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.itemView = itemView
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: PlatformMetrics.horizontalSpacing), count: columns),
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

/// Featured content hero banner with auto-advancement
struct HeroBanner<Item: Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    let subtitle: (Item) -> String?
    let imageURL: (Item) -> URL?
    var onSelect: (Item) -> Void = { _ in }
    
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !items.isEmpty {
                ZStack(alignment: .bottomLeading) {
                    // Background image
                    CachedAsyncImage(url: imageURL(items[currentIndex])) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ShimmerPlaceholder()
                    }
                    .frame(height: PlatformMetrics.heroBannerHeight)
                    .clipped()
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L10n.Content.featured)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(title(items[currentIndex]))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let sub = subtitle(items[currentIndex]) {
                            Text(sub)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 20) {
                            Button {
                                onSelect(items[currentIndex])
                            } label: {
                                Label(L10n.Player.play, systemImage: "play.fill")
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            // Page indicators
                            HStack(spacing: 8) {
                                ForEach(0..<min(items.count, 5), id: \.self) { index in
                                    Circle()
                                        .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                    .padding(PlatformMetrics.detailPadding)
                }
                .focused($isFocused)
                #if os(tvOS)
                .onMoveCommand { direction in
                    switch direction {
                    case .left:
                        previousItem()
                    case .right:
                        nextItem()
                    default:
                        break
                    }
                }
                #endif
            }
        }
        .onAppear {
            startAutoAdvance()
        }
        .onDisappear {
            stopAutoAdvance()
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                stopAutoAdvance()
            } else {
                startAutoAdvance()
            }
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
        withAnimation {
            currentIndex = (currentIndex + 1) % min(items.count, 5)
        }
    }
    
    private func previousItem() {
        withAnimation {
            currentIndex = currentIndex == 0 ? min(items.count - 1, 4) : currentIndex - 1
        }
    }
}

// MARK: - Skeleton Loading Views

/// Skeleton loading placeholder for a content card
struct SkeletonCard: View {
    let aspectRatio: CGFloat
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image skeleton
            ShimmerPlaceholder()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .cornerRadius(12)
            
            // Title skeleton
            ShimmerPlaceholder()
                .frame(height: 16)
                .frame(maxWidth: .infinity)
                .cornerRadius(4)
            
            // Subtitle skeleton
            ShimmerPlaceholder()
                .frame(height: 12)
                .frame(width: 100)
                .cornerRadius(4)
        }
    }
}

/// Skeleton loading row for category content
struct SkeletonRow: View {
    let cardCount: Int
    let aspectRatio: CGFloat
    let cardWidth: CGFloat
    
    init(cardCount: Int = 5, aspectRatio: CGFloat = 16/9, cardWidth: CGFloat = 0) {
        self.cardCount = cardCount
        self.aspectRatio = aspectRatio
        self.cardWidth = cardWidth > 0 ? cardWidth : PlatformMetrics.channelCardWidth
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header skeleton
            HStack(spacing: 12) {
                ShimmerPlaceholder()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
                
                ShimmerPlaceholder()
                    .frame(width: 200, height: 20)
                    .cornerRadius(4)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Cards skeleton
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

/// Full page skeleton loading
struct SkeletonPageView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: PlatformMetrics.sectionSpacing) {
                // Hero skeleton
                ShimmerPlaceholder()
                    .frame(height: PlatformMetrics.heroBannerHeight - 100)
                
                // Row skeletons
                SkeletonRow(cardCount: 5, aspectRatio: 16/9, cardWidth: PlatformMetrics.channelCardWidth)
                SkeletonRow(cardCount: 6, aspectRatio: 2/3, cardWidth: PlatformMetrics.posterCardWidth)
                SkeletonRow(cardCount: 6, aspectRatio: 2/3, cardWidth: PlatformMetrics.posterCardWidth)
            }
        }
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
            print("See all tapped")
        }
        
        CategoryHeader(
            title: "Action Movies",
            itemCount: 156
        )
        
        SkeletonRow()
    }
    .padding()
}
