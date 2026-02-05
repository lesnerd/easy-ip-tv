import SwiftUI

/// Main Live TV view with category navigation
struct LiveTVView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    @State private var selectedCategory: String?
    @State private var selectedChannel: Channel?
    @State private var showPlayer = false
    
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
            .navigationTitle(L10n.Navigation.liveTV)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let channel = selectedChannel {
                PlayerView(channel: channel)
            }
        }
    }
    
    // MARK: - Category List View
    
    private var categoryListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                // All Channels row
                if !contentViewModel.channels.isEmpty {
                    CategoryRow(
                        title: L10n.Content.allChannels,
                        icon: "tv",
                        itemCount: contentViewModel.channels.count
                    ) {
                        ForEach(contentViewModel.channels.prefix(10)) { channel in
                            ChannelCard(channel: channel) {
                                playChannel(channel)
                            } onLongPress: {
                                toggleFavorite(channel)
                            }
                            .frame(width: 300)
                        }
                    }
                }
                
                // Category rows
                ForEach(contentViewModel.channelCategories, id: \.self) { category in
                    let channels = contentViewModel.channels(in: category)
                    
                    CategoryRow(
                        title: category,
                        itemCount: channels.count
                    ) {
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
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Category Detail View
    
    private func categoryDetailView(category: String) -> some View {
        let channels = contentViewModel.channels(in: category)
        
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
                CategoryHeader(title: category, icon: "tv", itemCount: channels.count)
                
                // Channel grid
                CategoryGrid(items: channels, columns: 5) { channel in
                    ChannelCard(channel: channel) {
                        playChannel(channel)
                    } onLongPress: {
                        toggleFavorite(channel)
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
