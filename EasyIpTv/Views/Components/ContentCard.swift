import SwiftUI

/// Reusable card component for displaying content items -- Liquid Glass style
struct ContentCard: View {
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let isFavorite: Bool
    let aspectRatio: CGFloat
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}
    
    @Environment(\.colorScheme) private var scheme
    @State private var isPressed = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    
    init(
        title: String,
        subtitle: String? = nil,
        imageURL: URL? = nil,
        isFavorite: Bool = false,
        aspectRatio: CGFloat = 16/9,
        onTap: @escaping () -> Void = {},
        onLongPress: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.isFavorite = isFavorite
        self.aspectRatio = aspectRatio
        self.onTap = onTap
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: aspectRatio == 16/9 ? .fit : .fill)
                    } placeholder: {
                        placeholderImage
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .background(AppTheme.surfaceContainerHigh(scheme))
                    .clipped()
                    .cornerRadius(PlatformMetrics.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: PlatformMetrics.cardCornerRadius)
                            .stroke(cardBorderColor, lineWidth: cardBorderWidth)
                    )
                    #if !os(tvOS)
                    .shadow(
                        color: isHovered ? AppTheme.primary.opacity(0.25) : Color.black.opacity(0.2),
                        radius: isHovered ? 16 : 6,
                        y: isHovered ? 6 : 3
                    )
                    #endif
                    
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.tertiary)
                            .padding(5)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                            .padding(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .lineLimit(2)
                        .foregroundColor(AppTheme.onSurface(scheme))
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(CardButtonStyle())
        .tvOSFocusEffectDisabled()
        .focused($isFocused)
        #if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
        .contextMenu {
            Button {
                onLongPress()
            } label: {
                Label(
                    isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                    systemImage: isFavorite ? "heart.slash" : "heart"
                )
            }
        }
    }
    
    private var cardBorderColor: Color {
        #if os(tvOS)
        return isFocused ? AppTheme.primary.opacity(0.50) : AppTheme.glassBorder(scheme)
        #else
        return isHovered ? AppTheme.primary.opacity(0.40) : AppTheme.glassBorder(scheme)
        #endif
    }
    
    private var cardBorderWidth: CGFloat {
        #if os(tvOS)
        return isFocused ? 2 : 1
        #else
        return isHovered ? 1.5 : 0.5
        #endif
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(AppTheme.surfaceContainerHigh(scheme))
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme).opacity(0.4))
            }
    }
}

/// Custom button style for cards with focus/hover effects
struct CardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            #if os(tvOS)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .offset(y: isFocused ? -8 : 0)
            .overlay(
                RoundedRectangle(cornerRadius: PlatformMetrics.cardCornerRadius)
                    .stroke(
                        isFocused ? AppTheme.primary.opacity(0.6) : Color.clear,
                        lineWidth: 2.5
                    )
            )
            .shadow(
                color: isFocused ? AppTheme.primary.opacity(0.35) : .clear,
                radius: isFocused ? 25 : 0,
                y: isFocused ? 10 : 0
            )
            .brightness(isFocused ? 0.05 : 0)
            .animation(.easeInOut(duration: 0.25), value: isFocused)
            #else
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            #endif
    }
}

extension View {
    @ViewBuilder
    func tvOSFocusEffectDisabled() -> some View {
        #if os(tvOS)
        self.focusEffectDisabled()
        #else
        self
        #endif
    }
}

// MARK: - Channel Card

struct ChannelCard: View {
    let channel: Channel
    var nowPlaying: String? = nil
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}
    var onCatchup: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var scheme
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onTap()
        } label: {
            #if os(macOS)
            channelCardMacOS
            #else
            channelCardDefault
            #endif
        }
        .buttonStyle(CardButtonStyle())
        .tvOSFocusEffectDisabled()
        #if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
        .contextMenu {
            Button {
                onLongPress()
            } label: {
                Label(
                    channel.isFavorite ? L10n.Favorites.removeFromFavorites : L10n.Favorites.addToFavorites,
                    systemImage: channel.isFavorite ? "heart.slash" : "heart"
                )
            }
            if channel.hasCatchup, let onCatchup {
                Button {
                    onCatchup()
                } label: {
                    Label("Catchup", systemImage: "clock.arrow.circlepath")
                }
            }
        }
    }
    
    #if os(macOS)
    private var channelCardMacOS: some View {
        VStack(alignment: .leading, spacing: 0) {
            channelThumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    if let nowPlaying {
                        Text(nowPlaying)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    } else {
                        Text(channel.category)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if channel.hasCatchup {
                        Text("Catchup")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppTheme.catchupBadge.opacity(0.85), in: Capsule())
                    }
                    if channel.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(AppTheme.tertiary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 40)
            .background(Color(hex: 0x1A1A1E))
        }
        .background(Color(hex: 0x1A1A1E))
        .cornerRadius(PlatformMetrics.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: PlatformMetrics.cardCornerRadius)
                .stroke(AppTheme.glassBorder(scheme), lineWidth: 0.5)
        )
        .shadow(
            color: isHovered ? AppTheme.primary.opacity(0.20) : Color.black.opacity(0.15),
            radius: isHovered ? 12 : 4,
            y: isHovered ? 4 : 2
        )
    }
    #endif
    
    private var channelCardDefault: some View {
        ZStack(alignment: .bottom) {
            channelThumbnail
            
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.4), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if channel.hasCatchup {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 7))
                            Text("Catchup")
                                .font(AppTypography.micro)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.catchupBadge.opacity(0.85), in: Capsule())
                    }
                    Spacer()
                    if channel.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.tertiary)
                    }
                }
                
                Text(channel.name)
                    #if os(tvOS)
                    .font(.system(size: 16, weight: .bold))
                    #else
                    .font(AppTypography.cardTitle)
                    #endif
                    .lineLimit(1)
                    .foregroundColor(.white)
                
                if let nowPlaying {
                    Text(nowPlaying)
                        #if os(tvOS)
                        .font(.system(size: 13))
                        #else
                        .font(AppTypography.caption)
                        #endif
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                } else {
                    Text(channel.category)
                        #if os(tvOS)
                        .font(.system(size: 13))
                        #else
                        .font(AppTypography.caption)
                        #endif
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            #if os(tvOS)
            .padding(14)
            #else
            .padding(10)
            #endif
        }
        .background(Color(hex: 0x1A1A1E))
        .cornerRadius(PlatformMetrics.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: PlatformMetrics.cardCornerRadius)
                .stroke(AppTheme.glassBorder(scheme), lineWidth: 0.5)
        )
        #if !os(tvOS)
        .shadow(
            color: isHovered ? AppTheme.primary.opacity(0.20) : Color.black.opacity(0.15),
            radius: isHovered ? 12 : 4,
            y: isHovered ? 4 : 2
        )
        #endif
    }
    
    @ViewBuilder
    private var channelThumbnail: some View {
        Color.clear
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                CachedAsyncImage(url: channel.logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.primary.opacity(0.15),
                                    AppTheme.secondary.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Text(channel.name.prefix(3).uppercased())
                                #if os(tvOS)
                                .font(.system(size: 28, weight: .black))
                                #else
                                .font(.system(size: 14, weight: .heavy))
                                #endif
                                .foregroundColor(.white.opacity(0.15))
                        }
                }
            )
            .clipped()
    }
}

// MARK: - Movie Card

struct MovieCard: View {
    let movie: Movie
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}
    
    var body: some View {
        ContentCard(
            title: movie.title,
            subtitle: movie.year != nil ? String(movie.year!) : movie.category,
            imageURL: movie.posterURL,
            isFavorite: movie.isFavorite,
            aspectRatio: 2/3,
            onTap: onTap,
            onLongPress: onLongPress
        )
    }
}

// MARK: - Show Card

struct ShowCard: View {
    let show: Show
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}
    
    var body: some View {
        ContentCard(
            title: show.title,
            subtitle: "\(show.totalEpisodes) episodes",
            imageURL: show.posterURL,
            isFavorite: show.isFavorite,
            aspectRatio: 2/3,
            onTap: onTap,
            onLongPress: onLongPress
        )
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 40) {
        ContentCard(
            title: "Sample Channel",
            subtitle: "Entertainment",
            isFavorite: true
        )
        .frame(width: 300)
        
        ContentCard(
            title: "Sample Movie",
            subtitle: "2024",
            isFavorite: false,
            aspectRatio: 2/3
        )
        .frame(width: 200)
    }
    .padding()
}
