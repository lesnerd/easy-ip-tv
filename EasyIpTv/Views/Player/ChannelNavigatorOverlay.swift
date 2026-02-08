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
    
    private var stripSpacing: CGFloat {
        #if os(tvOS)
        return 40
        #elseif os(macOS)
        return 20
        #else
        return 16
        #endif
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom channel strip
            VStack(spacing: 0) {
                // Header bar with category pills and close button
                HStack(alignment: .center) {
                    // Close button (leading)
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Current channel info
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(currentChannel.name)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 30, height: 30)
                }
                .padding(.horizontal, PlatformMetrics.contentPadding + 10)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Category pill bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryPill(
                            title: L10n.Content.allChannels,
                            isSelected: selectedCategory == nil
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = nil
                            }
                        }
                        
                        ForEach(categories, id: \.self) { category in
                            CategoryPill(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PlatformMetrics.contentPadding + 10)
                }
                .platformFocusSection()
                .padding(.bottom, 16)
                
                // Horizontal channel strip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: stripSpacing) {
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
                        .padding(.horizontal, PlatformMetrics.contentPadding + 10)
                        .padding(.bottom, PlatformMetrics.contentPadding)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedChannelId = currentChannel.id
                            withAnimation {
                                proxy.scrollTo(currentChannel.id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: selectedCategory) { _, _ in
                        // Reset focus when category changes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let first = filteredChannels.first {
                                focusedChannelId = first.id
                                withAnimation {
                                    proxy.scrollTo(first.id, anchor: .leading)
                                }
                            }
                        }
                    }
                }
                .platformFocusSection()
            }
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.9), Color.black.opacity(0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    var onSelect: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(pillBackground)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #else
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        #endif
    }
    
    @ViewBuilder
    private var pillBackground: some View {
        if isSelected {
            Capsule().fill(Color.white.opacity(0.3))
        } else {
            #if os(tvOS)
            Capsule().fill(isFocused ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            #else
            Capsule().fill(isHovered ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            #endif
        }
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
        return CGSize(width: 240, height: 140)
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
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.3))
                    
                    CachedAsyncImage(url: channel.logoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(14)
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
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isCurrentChannel ? Color.green : (isFocused ? Color.white : Color.clear), lineWidth: 3)
                )
                #if os(tvOS)
                .shadow(color: isFocused ? .black.opacity(0.5) : .clear, radius: 20, y: 10)
                #endif
                
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
