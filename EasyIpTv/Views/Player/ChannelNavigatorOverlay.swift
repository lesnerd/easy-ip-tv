import SwiftUI

/// Full-screen channel browser overlay -- Liquid Glass style.
/// Appears over the player when the user taps the channel list button.
struct ChannelNavigatorOverlay: View {
    let channels: [Channel]
    let currentChannel: Channel
    var onSelectChannel: (Channel) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    
    @ObservedObject private var epgService = EPGService.shared
    @FocusState private var focusedChannelId: String?
    @State private var selectedCategory: String?
    @State private var searchText = ""
    
    private var categories: [String] {
        Array(Set(channels.map { $0.category })).sorted()
    }
    
    private var filteredChannels: [Channel] {
        var result = channels
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    private var horizontalPad: CGFloat {
        #if os(tvOS)
        return 60
        #elseif os(macOS)
        return 40
        #else
        return 20
        #endif
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.70)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 0) {
                nowPlayingBanner
                
                filterBar
                
                channelList
            }
            #if os(macOS)
            .frame(maxWidth: 800)
            #endif
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Now Playing Banner
    
    private var nowPlayingBanner: some View {
        let program = currentProgram(for: currentChannel)
        
        return HStack(spacing: 16) {
            CachedAsyncImage(url: currentChannel.logoURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "tv")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(width: 56, height: 42)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    LivePulseIndicator(size: 5)
                    
                    if let num = currentChannel.channelNumber {
                        Text("Ch \(num)")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Text(currentChannel.name)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                if let program {
                    Text(program.title)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    GlowProgressBar(
                        progress: program.progress,
                        height: 3,
                        trackColor: Color.white.opacity(0.12),
                        barColor: AppTheme.primary
                    )
                    .frame(maxWidth: 220)
                }
            }
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Back")
                        .font(AppTypography.label)
                }
                .foregroundColor(AppTheme.onPrimaryContainer)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(AppTheme.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, horizontalPad)
        .padding(.vertical, 14)
        .background(
            Color.white.opacity(0.06)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
    }
    
    // MARK: - Filter Bar (categories + search)
    
    private var filterBar: some View {
        VStack(spacing: 12) {
            #if !os(tvOS)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                
                TextField("Search channels...", text: $searchText)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: Capsule())
            .padding(.horizontal, horizontalPad)
            #endif
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                .padding(.horizontal, horizontalPad)
            }
            .platformFocusSection()
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Channel List
    
    private var channelList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredChannels) { channel in
                        NavigatorChannelRow(
                            channel: channel,
                            isCurrent: channel.id == currentChannel.id,
                            program: currentProgram(for: channel)
                        ) {
                            onSelectChannel(channel)
                        }
                        .focused($focusedChannelId, equals: channel.id)
                        .id(channel.id)
                    }
                }
                .padding(.horizontal, horizontalPad)
                .padding(.bottom, 40)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focusedChannelId = currentChannel.id
                    withAnimation {
                        proxy.scrollTo(currentChannel.id, anchor: .center)
                    }
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let first = filteredChannels.first {
                        focusedChannelId = first.id
                        withAnimation {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }
        }
        .platformFocusSection()
    }
    
    // MARK: - EPG Helper
    
    private func currentProgram(for channel: Channel) -> EPGProgram? {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId
        guard let key else { return nil }
        return epgService.nowPlaying(for: key)
    }
}

// MARK: - Navigator Channel Row

private struct NavigatorChannelRow: View {
    let channel: Channel
    let isCurrent: Bool
    let program: EPGProgram?
    var onSelect: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 14) {
                if let number = channel.channelNumber {
                    Text("\(number)")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 32, alignment: .trailing)
                }
                
                CachedAsyncImage(url: channel.logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "tv")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(width: 44, height: 32)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(channel.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if isCurrent {
                            LiveBadge()
                        }
                    }
                    
                    if let program {
                        HStack(spacing: 8) {
                            Text(program.title)
                                .font(AppTypography.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                            
                            Text(program.timeRange)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                
                Spacer()
                
                if let program {
                    GlowProgressBar(
                        progress: program.progress,
                        height: 3,
                        trackColor: Color.white.opacity(0.08),
                        barColor: isCurrent ? AppTheme.primary : Color.white.opacity(0.30)
                    )
                    .frame(width: 50)
                }
                
                if channel.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.tertiary)
                }
                
                if isCurrent {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.primary)
                } else {
                    Image(systemName: "play.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(isHovered ? 0.8 : 0.2))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isCurrent ? AppTheme.primary.opacity(0.35) : Color.clear,
                        lineWidth: isCurrent ? 1 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        #if !os(tvOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        #endif
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        #endif
    }
    
    private var rowBackground: Color {
        if isCurrent {
            return AppTheme.primary.opacity(0.12)
        }
        #if os(tvOS)
        return isFocused ? Color.white.opacity(0.10) : Color.white.opacity(0.03)
        #else
        return isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03)
        #endif
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
                .font(AppTypography.label)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(pillBackground)
                .foregroundStyle(isSelected ? AppTheme.onPrimaryContainer : .white.opacity(0.7))
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
            Capsule().fill(AppTheme.primary)
        } else {
            #if os(tvOS)
            Capsule().fill(isFocused ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            #else
            Capsule().fill(isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            #endif
        }
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
