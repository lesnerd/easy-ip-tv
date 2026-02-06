import SwiftUI

/// Overlay for navigating channels while watching live TV - appears at bottom of screen
struct ChannelNavigatorOverlay: View {
    let channels: [Channel]
    let currentChannel: Channel
    var onSelectChannel: (Channel) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    
    @FocusState private var focusedChannelId: String?
    @State private var selectedCategory: String?
    
    private var categories: [String] {
        Array(Set(channels.map { $0.category })).sorted()
    }
    
    private var filteredChannels: [Channel] {
        if let category = selectedCategory {
            return channels.filter { $0.category == category }
        }
        return channels
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom channel strip
            VStack(spacing: 0) {
                // Header bar with category filter
                HStack {
                    // Category filter
                    Menu {
                        Button("All Categories") {
                            selectedCategory = nil
                        }
                        Divider()
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                            Text(selectedCategory ?? "All Categories")
                                .font(.callout)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // Current channel info
                    HStack(spacing: 12) {
                        Text(L10n.Player.nowPlaying)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(currentChannel.name)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, PlatformMetrics.contentPadding)
                .padding(.vertical, 16)
                
                // Horizontal channel strip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 20) {
                            ForEach(filteredChannels) { channel in
                                ChannelStripCard(
                                    channel: channel,
                                    isCurrentChannel: channel.id == currentChannel.id,
                                    isFocused: focusedChannelId == channel.id
                                ) {
                                    onSelectChannel(channel)
                                }
                                .focused($focusedChannelId, equals: channel.id)
                                .id(channel.id)
                            }
                        }
                        .padding(.horizontal, PlatformMetrics.contentPadding)
                        .padding(.bottom, PlatformMetrics.contentPadding)
                    }
                    .onAppear {
                        // Focus and scroll to current channel
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedChannelId = currentChannel.id
                            withAnimation {
                                proxy.scrollTo(currentChannel.id, anchor: .center)
                            }
                        }
                    }
                }
                .platformFocusSection()
            }
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Channel Strip Card (for bottom strip)

struct ChannelStripCard: View {
    let channel: Channel
    let isCurrentChannel: Bool
    let isFocused: Bool
    var onSelect: () -> Void = {}
    
    private var cardSize: CGSize {
        #if os(tvOS)
        return CGSize(width: 200, height: 120)
        #elseif os(macOS)
        return CGSize(width: 160, height: 96)
        #else
        return CGSize(width: 140, height: 84)
        #endif
    }
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 10) {
                // Channel logo
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                    
                    CachedAsyncImage(url: channel.logoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(12)
                    } placeholder: {
                        Image(systemName: "tv")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    // Currently playing indicator
                    if isCurrentChannel {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                    
                    // Favorite indicator
                    if channel.isFavorite {
                        VStack {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: cardSize.width, height: cardSize.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentChannel ? Color.green : (isFocused ? Color.white : Color.clear), lineWidth: 3)
                )
                
                // Channel info
                VStack(spacing: 4) {
                    if let number = channel.channelNumber {
                        Text("\(number)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Text(channel.name)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: cardSize.width)
                }
            }
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #endif
    }
}

// MARK: - Preview

#Preview {
    let channels = [
        Channel(name: "Channel 1", streamURL: URL(string: "http://test.com")!, category: "Sports", channelNumber: 1),
        Channel(name: "Channel 2", streamURL: URL(string: "http://test.com")!, category: "Sports", channelNumber: 2, isFavorite: true),
        Channel(name: "Channel 3", streamURL: URL(string: "http://test.com")!, category: "News", channelNumber: 3),
        Channel(name: "Channel 4", streamURL: URL(string: "http://test.com")!, category: "Movies", channelNumber: 4),
        Channel(name: "Channel 5", streamURL: URL(string: "http://test.com")!, category: "Movies", channelNumber: 5)
    ]
    
    return ZStack {
        Color.black
            .ignoresSafeArea()
        
        Text("Video Playing")
            .foregroundStyle(.white.opacity(0.3))
        
        ChannelNavigatorOverlay(
            channels: channels,
            currentChannel: channels[1]
        )
    }
}
