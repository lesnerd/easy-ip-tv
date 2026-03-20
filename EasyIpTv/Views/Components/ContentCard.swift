import SwiftUI

/// Reusable card component for displaying content items
struct ContentCard: View {
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let isFavorite: Bool
    let aspectRatio: CGFloat
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}
    
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
                // Image
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
                    .background(Color.gray.opacity(0.15))
                    .clipped()
                    .cornerRadius(10)
                    #if !os(tvOS)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHovered ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: isHovered ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.15), radius: isHovered ? 12 : 4, y: isHovered ? 4 : 2)
                    #endif
                    
                    // Favorite indicator
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .padding(6)
                    }
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(CardButtonStyle())
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
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
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
            .shadow(color: .black.opacity(isFocused ? 0.4 : 0), radius: isFocused ? 30 : 0, y: isFocused ? 12 : 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            #else
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
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
    
    var body: some View {
        ContentCard(
            title: channel.name,
            subtitle: nowPlaying ?? channel.category,
            imageURL: channel.logoURL,
            isFavorite: channel.isFavorite,
            aspectRatio: 16/9,
            onTap: onTap,
            onLongPress: onLongPress
        )
        .overlay(alignment: .topLeading) {
            if channel.hasCatchup {
                if let onCatchup {
                    Button {
                        onCatchup()
                    } label: {
                        catchupBadge
                    }
                    .buttonStyle(.plain)
                } else {
                    catchupBadge
                }
            }
        }
    }
    
    private var catchupBadge: some View {
        Label("Catchup", systemImage: "clock.arrow.circlepath")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.85), in: Capsule())
            .padding(6)
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
