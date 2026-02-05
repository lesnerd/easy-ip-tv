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
            VStack(alignment: .leading, spacing: 12) {
                // Image
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            placeholderImage
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .clipped()
                    .cornerRadius(12)
                    
                    // Favorite indicator
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
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
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}

/// Custom button style for cards with focus effects
struct CardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(radius: isFocused ? 20 : 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Channel Card

struct ChannelCard: View {
    let channel: Channel
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}
    
    var body: some View {
        ContentCard(
            title: channel.name,
            subtitle: channel.category,
            imageURL: channel.logoURL,
            isFavorite: channel.isFavorite,
            aspectRatio: 16/9,
            onTap: onTap,
            onLongPress: onLongPress
        )
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
