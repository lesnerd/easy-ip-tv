import SwiftUI

/// Overlay for navigating channels while watching live TV
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
        HStack(spacing: 0) {
            Spacer()
            
            // Navigator panel
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(L10n.Content.allChannels)
                        .font(.headline)
                    
                    Spacer()
                    
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
                        HStack {
                            Text(selectedCategory ?? "All Categories")
                                .font(.callout)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Divider()
                
                // Channel list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredChannels) { channel in
                                NavigatorChannelRow(
                                    channel: channel,
                                    isCurrentChannel: channel.id == currentChannel.id
                                ) {
                                    onSelectChannel(channel)
                                }
                                .focused($focusedChannelId, equals: channel.id)
                                .id(channel.id)
                            }
                        }
                        .padding(.vertical, 8)
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
            }
            .frame(width: 500)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.trailing, 40)
            .padding(.vertical, 60)
        }
        .transition(.move(edge: .trailing))
    }
}

// MARK: - Navigator Channel Row

struct NavigatorChannelRow: View {
    let channel: Channel
    let isCurrentChannel: Bool
    var onSelect: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Channel number
                if let number = channel.channelNumber {
                    Text("\(number)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                
                // Channel logo
                AsyncImage(url: channel.logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        Image(systemName: "tv")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 50, height: 32)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                
                // Channel name
                Text(channel.name)
                    .font(.callout)
                    .lineLimit(1)
                
                Spacer()
                
                // Favorite indicator
                if channel.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Currently playing indicator
                if isCurrentChannel {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Now Playing")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
    
    private var backgroundColor: Color {
        if isCurrentChannel {
            return Color.accentColor.opacity(0.3)
        } else if isFocused {
            return Color.gray.opacity(0.2)
        }
        return Color.clear
    }
}

// MARK: - Quick Channel Switch View

/// Compact view for quick channel switching with up/down navigation
struct QuickChannelSwitchView: View {
    let previousChannel: Channel?
    let currentChannel: Channel
    let nextChannel: Channel?
    
    var onSwitchToPrevious: () -> Void = {}
    var onSwitchToNext: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 12) {
            // Previous channel
            if let prev = previousChannel {
                Button {
                    onSwitchToPrevious()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                        Text(prev.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Current channel
            HStack(spacing: 12) {
                AsyncImage(url: currentChannel.logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        Image(systemName: "tv")
                            .font(.title2)
                    }
                }
                .frame(width: 60, height: 40)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    if let number = currentChannel.channelNumber {
                        Text("Ch. \(number)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(currentChannel.name)
                        .font(.callout)
                        .fontWeight(.medium)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Next channel
            if let next = nextChannel {
                Button {
                    onSwitchToNext()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                        Text(next.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let channels = [
        Channel(name: "Channel 1", streamURL: URL(string: "http://test.com")!, category: "Sports", channelNumber: 1),
        Channel(name: "Channel 2", streamURL: URL(string: "http://test.com")!, category: "Sports", channelNumber: 2, isFavorite: true),
        Channel(name: "Channel 3", streamURL: URL(string: "http://test.com")!, category: "News", channelNumber: 3)
    ]
    
    return ZStack {
        Color.black
        ChannelNavigatorOverlay(
            channels: channels,
            currentChannel: channels[1]
        )
    }
}
