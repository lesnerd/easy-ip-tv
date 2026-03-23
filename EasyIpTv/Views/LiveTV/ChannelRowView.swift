import SwiftUI

/// Compact channel row for lists and navigation -- Liquid Glass style
struct ChannelRowView: View {
    let channel: Channel
    let isSelected: Bool
    var onSelect: () -> Void = {}
    
    @Environment(\.colorScheme) private var scheme
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 14) {
                if let number = channel.channelNumber {
                    Text("\(number)")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                        .frame(width: 36, alignment: .trailing)
                }
                
                CachedAsyncImage(url: channel.logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "tv")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                }
                .frame(width: 48, height: 36)
                .background(AppTheme.surfaceContainerHigh(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(channel.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppTheme.onSurface(scheme))
                    .lineLimit(1)
                
                Spacer()
                
                if channel.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.tertiary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                            ? AppTheme.primary.opacity(0.12)
                            : AppTheme.surfaceContainerLow(scheme).opacity(0.01)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? AppTheme.primary.opacity(0.30) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isFocused ? Color.white.opacity(0.10) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #endif
    }
}

// MARK: - Channel List View

struct ChannelListView: View {
    let channels: [Channel]
    let selectedChannel: Channel?
    var onSelect: (Channel) -> Void = { _ in }
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
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
    
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focusedChannelId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.Content.allChannels)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppTheme.onSurface(scheme))
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)
            
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
        .frame(width: PlatformMetrics.usesFocusScaling ? 500 : 400)
        .glassPanel(cornerRadius: 16)
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
