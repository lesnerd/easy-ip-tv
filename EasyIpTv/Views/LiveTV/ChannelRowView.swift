import SwiftUI

/// Compact channel row for lists and navigation -- Liquid Glass style
struct ChannelRowView: View {
    let channel: Channel
    let isSelected: Bool
    var onSelect: () -> Void = {}
    
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var epgService = EPGService.shared
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
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(channel.name)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppTheme.onSurface(scheme))
                        .lineLimit(2)
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        programDetails(at: context.date)
                    }
                }

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
    @ViewBuilder
    private func programDetails(at date: Date) -> some View {
        let keys = [channel.streamId.map { String($0) }, channel.epgChannelId, channel.tvgId].compactMap { $0 }
        let programs = keys.compactMap { epgService.programsByChannel[$0] }.first { !$0.isEmpty } ?? []
        let current = programs.first { $0.start <= date && $0.end > date }
        let next = programs.filter { $0.start > date }.min { $0.start < $1.start }
        if let current {
            Text(current.title)
                .font(AppTypography.caption)
                .lineLimit(2)
            Text(current.timeRange)
                .font(AppTypography.caption)
                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
            ProgressView(value: max(0, min(1, date.timeIntervalSince(current.start) / max(1, current.end.timeIntervalSince(current.start)))))
                .tint(AppTheme.primary)
        } else {
            Text("Program information unavailable")
                .font(AppTypography.caption)
                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
        }
        if let next {
            Text("Next: \(next.title) · \(next.timeRange)")
                .font(AppTypography.caption)
                .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                .lineLimit(2)
        }
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
