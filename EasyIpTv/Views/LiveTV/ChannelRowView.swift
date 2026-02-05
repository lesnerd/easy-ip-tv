import SwiftUI

/// Compact channel row for lists and navigation
struct ChannelRowView: View {
    let channel: Channel
    let isSelected: Bool
    var onSelect: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 16) {
                // Channel number
                if let number = channel.channelNumber {
                    Text("\(number)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                
                // Channel logo
                CachedAsyncImage(url: channel.logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "tv")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60, height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                
                // Channel name
                Text(channel.name)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                // Favorite indicator
                if channel.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Channel List View

struct ChannelListView: View {
    let channels: [Channel]
    let selectedChannel: Channel?
    var onSelect: (Channel) -> Void = { _ in }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(channels) { channel in
                    ChannelRowView(
                        channel: channel,
                        isSelected: channel.id == selectedChannel?.id
                    ) {
                        onSelect(channel)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Mini Channel Navigator

struct MiniChannelNavigator: View {
    let channels: [Channel]
    let currentChannel: Channel
    var onSelect: (Channel) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    
    @FocusState private var focusedChannelId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.Content.allChannels)
                    .font(.headline)
                Spacer()
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
            
            // Channel list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(channels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isSelected: channel.id == currentChannel.id
                            ) {
                                onSelect(channel)
                            }
                            .focused($focusedChannelId, equals: channel.id)
                            .id(channel.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    focusedChannelId = currentChannel.id
                    proxy.scrollTo(currentChannel.id, anchor: .center)
                }
            }
        }
        .frame(width: 500)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    let channels = [
        Channel(name: "Channel 1", streamURL: URL(string: "http://test.com")!, category: "Test", channelNumber: 1),
        Channel(name: "Channel 2", streamURL: URL(string: "http://test.com")!, category: "Test", channelNumber: 2, isFavorite: true),
        Channel(name: "Channel 3", streamURL: URL(string: "http://test.com")!, category: "Test", channelNumber: 3)
    ]
    
    return VStack {
        ChannelRowView(channel: channels[0], isSelected: false)
        ChannelRowView(channel: channels[1], isSelected: true)
    }
    .padding()
}
