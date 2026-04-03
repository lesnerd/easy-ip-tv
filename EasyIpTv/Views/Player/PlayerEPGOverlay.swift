import SwiftUI

/// Full-screen EPG guide overlay shown while watching live TV.
/// On tvOS: split-screen layout with video PiP (top-left), trending/upcoming cards (top-right),
/// and channel guide grid (bottom half).
/// On iOS/macOS: full-screen overlay with day pills, hero, and EPG grid.
struct PlayerEPGOverlay: View {
    let channels: [Channel]
    let currentChannel: Channel
    var onSelectChannel: (Channel) -> Void = { _ in }
    var onPlayCatchup: ((Channel, EPGProgram) -> Void)? = nil
    var onDismiss: () -> Void = {}
    
    @ObservedObject private var epgService = EPGService.shared
    @State private var selectedDayOffset = 0
    @State private var epgLoadingState: EPGLoadingState = .idle
    
    #if os(tvOS)
    @EnvironmentObject var contentViewModel: ContentViewModel
    #endif
    
    private enum EPGLoadingState {
        case idle, loading, loaded
    }
    
    private var dayOptions: [(id: Int, title: String)] {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE"
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            let title = offset == 0 ? "Today" : dayFmt.string(from: date)
            return (id: offset, title: title)
        }
    }
    
    private var timelineStart: Date {
        let cal = Calendar.current
        let now = Date()
        if selectedDayOffset == 0 {
            return cal.date(bySettingHour: cal.component(.hour, from: now), minute: 0, second: 0, of: now)
                ?? now
        } else {
            let today = cal.startOfDay(for: now)
            let targetDay = cal.date(byAdding: .day, value: selectedDayOffset, to: today)!
            return cal.date(bySettingHour: 20, minute: 0, second: 0, of: targetDay)
                ?? targetDay
        }
    }
    
    private let hourWidth: CGFloat = {
        #if os(tvOS)
        return 280
        #elseif os(macOS)
        return 220
        #else
        return 180
        #endif
    }()
    
    private var channelLabelWidth: CGFloat {
        #if os(tvOS)
        return 140
        #elseif os(macOS)
        return 140
        #else
        return 90
        #endif
    }
    
    private var epgRowHeight: CGFloat {
        #if os(tvOS)
        return 68
        #else
        return 52
        #endif
    }
    
    var body: some View {
        #if os(tvOS)
        tvosBody
        #else
        ZStack {
            Color.black.opacity(0.80)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 0) {
                topBar
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        dayPills
                            .padding(.vertical, 12)
                        
                        nowPlayingHero
                            .padding(.bottom, 16)
                        
                        epgGrid
                    }
                }
                .frame(maxHeight: .infinity)
                
                nowPlayingBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        #endif
    }
    
    private func isMatchingChannel(_ a: Channel, _ b: Channel) -> Bool {
        if a.id == b.id { return true }
        if a.name == b.name { return true }
        if a.streamURL == b.streamURL { return true }
        if let aId = a.streamId, let bId = b.streamId, aId == bId { return true }
        if let aTvg = a.tvgId, let bTvg = b.tvgId, aTvg == bTvg, !aTvg.isEmpty { return true }
        return false
    }
    
    // MARK: - Ordered Channel List (current channel first, same category, wraps around)
    
    private var orderedChannelList: [Channel] {
        let maxCount = 40
        guard let idx = channels.firstIndex(where: { isMatchingChannel($0, currentChannel) }) else {
            var result = [currentChannel]
            result += channels.filter { !isMatchingChannel($0, currentChannel) }.prefix(maxCount - 1)
            return result
        }
        var result = [channels[idx]]
        result += channels[(idx + 1)...].prefix(maxCount - 1)
        if result.count < maxCount {
            result += channels[..<idx].prefix(maxCount - result.count)
        }
        return result
    }
    
    #if os(tvOS)
    private var tvosChannelList: [Channel] { orderedChannelList }
    
    // MARK: - tvOS Split-Screen Layout
    
    private func fetchEPGForVisibleChannels(forceRefresh: Bool = false) async {
        let channelList = tvosChannelList
        epgLoadingState = .loading
        if forceRefresh {
            await contentViewModel.forceRefreshEPGForChannels(channelList)
        } else {
            await contentViewModel.fetchEPGForChannels(channelList)
        }
        epgLoadingState = .loaded
    }
    
    private var tvosBody: some View {
        ZStack {
            LiquidGradientBackground(intensity: 0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section: video space (left) + upcoming card (right)
                HStack(alignment: .top, spacing: 32) {
                    Color.clear
                        .frame(width: 880, height: 440)
                        .focusSection()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        tvosUpcomingCard
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .focusSection()
                }
                .padding(.leading, 60)
                .padding(.trailing, 48)
                .padding(.top, 60)
                
                // Bottom section: Channel Guide
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                LinearGradient(colors: [AppTheme.primary, AppTheme.primary.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                            )
                        
                        Text("Channel Guide")
                            .font(.system(size: 26, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        tvosTimeRangeLabel
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 14)
                    
                    tvosEPGTimeHeader
                        .padding(.horizontal, 4)
                    
                    ZStack {
                        ScrollView(.vertical, showsIndicators: false) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(tvosChannelList) { channel in
                                        tvosEPGChannelRow(for: channel)
                                    }
                                }
                                .padding(.bottom, 24)
                            }
                        }
                        
                        if epgLoadingState == .loading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(AppTheme.primary)
                                    .scaleEffect(1.2)
                                Text("Loading schedule...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .padding(.horizontal, 48)
                .padding(.bottom, 24)
                .padding(.top, 10)
                .focusSection()
            }
        }
        .onExitCommand {
            onDismiss()
        }
        .task(id: currentChannel.id) {
            await fetchEPGForVisibleChannels(forceRefresh: true)
        }
        .transition(.opacity)
    }
    
    // MARK: - tvOS EPG Time Header (restyled)
    
    private var tvosEPGTimeHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "tv")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                Text("CHANNEL")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(width: 170, alignment: .leading)
            .padding(.leading, 24)
            
            ForEach(0..<6, id: \.self) { slotOffset in
                let date = Calendar.current.date(byAdding: .minute, value: slotOffset * 30, to: timelineStart)!
                let isNow = slotOffset == 0 && selectedDayOffset == 0
                
                HStack(spacing: 4) {
                    if isNow {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 5, height: 5)
                    }
                    Text(formatTime(date))
                        .font(.system(size: 13, weight: isNow ? .bold : .medium, design: .rounded))
                        .foregroundColor(isNow ? AppTheme.primary : .white.opacity(0.35))
                }
                .frame(width: hourWidth / 2, alignment: .leading)
            }
        }
        .frame(height: 36)
        .background(.ultraThinMaterial.opacity(0.5))
        .environment(\.colorScheme, .dark)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - tvOS EPG Channel Row (restyled)
    
    @ViewBuilder
    private func tvosEPGChannelRow(for channel: Channel) -> some View {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId ?? ""
        let programs = epgService.upcoming(for: key)
        let isCurrent = isMatchingChannel(channel, currentChannel)
        
        HStack(spacing: 0) {
            Button {
                onSelectChannel(channel)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isCurrent
                                    ? AppTheme.primary.opacity(0.15)
                                    : Color.white.opacity(0.05)
                            )
                        
                        if let logoURL = channel.logoURL {
                            CachedAsyncImage(url: logoURL) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Image(systemName: "tv")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                            .padding(4)
                        } else {
                            Image(systemName: "tv")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCurrent ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.name)
                            .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isCurrent ? .white : .white.opacity(0.8))
                            .lineLimit(1)
                        
                        if let num = channel.channelNumber {
                            Text("Ch. \(num)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                .frame(width: 150, alignment: .leading)
                .padding(.leading, 24)
            }
            .buttonStyle(EPGChannelButtonStyle())
            .focusEffectDisabled()
            
            if programs.isEmpty {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.02))
                        .frame(width: hourWidth * 3, height: 44)
                        .overlay {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.12))
                                Text("No schedule available")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.12))
                            }
                        }
                }
            } else {
                HStack(spacing: 2) {
                    ForEach(programs.prefix(8)) { program in
                        tvosEPGProgramBlock(channel: channel, program: program, isCurrent: isCurrent)
                    }
                }
            }
        }
        .frame(height: 56)
        .padding(.vertical, 1)
        .background(
            isCurrent
                ? LinearGradient(
                    colors: [AppTheme.primary.opacity(0.08), AppTheme.primary.opacity(0.03)],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - tvOS EPG Program Block (modern)
    
    private func tvosEPGProgramBlock(channel: Channel, program: EPGProgram, isCurrent: Bool) -> some View {
        let duration = program.end.timeIntervalSince(program.start) / 3600.0
        let width = max(CGFloat(120), hourWidth * CGFloat(duration))
        let isNow = program.isNowPlaying
        
        return Button {
            if isNow {
                onSelectChannel(channel)
            } else if channel.hasCatchup, program.end < Date() {
                onPlayCatchup?(channel, program)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if isNow {
                        LivePulseIndicator(size: 6)
                    }
                    Text(program.title)
                        .font(.system(size: 14, weight: isNow ? .bold : .medium))
                        .foregroundColor(isNow ? .white : .white.opacity(0.55))
                        .lineLimit(1)
                }
                
                Text(program.timeRange)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: width, height: 48, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isNow && isCurrent
                            ? AppTheme.primary.opacity(0.18)
                            : isNow
                                ? Color.white.opacity(0.08)
                                : Color.white.opacity(0.04)
                    )
                    .background(
                        isNow
                            ? RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                            : nil
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isNow && isCurrent
                            ? AppTheme.primary.opacity(0.35)
                            : isNow
                                ? AppTheme.primary.opacity(0.15)
                                : Color.white.opacity(0.06),
                        lineWidth: isNow ? 1 : 0.5
                    )
            )
            .overlay(alignment: .bottom) {
                if isNow {
                    GlowProgressBar(
                        progress: program.progress,
                        height: 2.5,
                        trackColor: AppTheme.primary.opacity(0.06),
                        barColor: AppTheme.primary
                    )
                    .clipShape(Capsule())
                    .padding(.horizontal, 4)
                    .padding(.bottom, 3)
                }
            }
        }
        .buttonStyle(EPGProgramButtonStyle())
        .focusEffectDisabled()
    }
    
    // MARK: - Upcoming Card
    
    @FocusState private var upcomingFocused: Bool
    
    private var tvosUpcomingCard: some View {
        let key = currentChannel.streamId.map { "\($0)" } ?? currentChannel.epgChannelId ?? currentChannel.tvgId ?? ""
        let upcoming = epgService.upcoming(for: key)
        let nextProgram = upcoming.first(where: { !$0.isNowPlaying })
        
        return Button {
            // Informational - no action needed
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.primary)
                    Text("UPCOMING ON \(currentChannel.name)")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(AppTheme.primary)
                        .lineLimit(1)
                }
                
                if let program = nextProgram {
                    Text(program.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(formatUpcomingTime(program.start))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                } else {
                    Text("No upcoming programs")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(upcomingFocused ? AppTheme.primary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: upcomingFocused ? 1.5 : 0.5)
            )
            .scaleEffect(upcomingFocused ? 1.03 : 1.0)
            .shadow(color: upcomingFocused ? AppTheme.primary.opacity(0.3) : .clear, radius: 12, y: 6)
            .animation(.easeInOut(duration: 0.2), value: upcomingFocused)
        }
        .buttonStyle(.plain)
        .focused($upcomingFocused)
        .focusEffectDisabled()
    }
    
    // MARK: - Time Range Label
    
    private var tvosTimeRangeLabel: some View {
        let endTime = Calendar.current.date(byAdding: .hour, value: 3, to: timelineStart) ?? timelineStart
        
        return HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
            Text("\(formatTime(timelineStart)) \u{2014} \(formatTime(endTime))")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    private func formatUpcomingTime(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        
        if cal.isDateInToday(date) {
            f.dateFormat = "h:mm a"
            return "Today, \(f.string(from: date))"
        } else if cal.isDateInTomorrow(date) {
            f.dateFormat = "h:mm a"
            return "Tomorrow, \(f.string(from: date))"
        } else {
            f.dateFormat = "EEEE, h:mm a"
            return f.string(from: date)
        }
    }
    #endif
    
    // MARK: - Top Bar (iOS/macOS)
    
    private var topBarPadding: CGFloat {
        #if os(tvOS)
        return 60
        #else
        return 20
        #endif
    }
    
    #if !os(tvOS)
    private var topBar: some View {
        HStack {
            Text("Live")
                .font(AppTypography.sectionTitle)
                .foregroundColor(.white)
            
            Spacer()
            
            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, topBarPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    #endif
    
    // MARK: - Day Pills (iOS/macOS)
    
    #if !os(tvOS)
    private var dayPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(dayOptions, id: \.id) { day in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDayOffset = day.id
                        }
                    } label: {
                        Text(day.title)
                            .font(AppTypography.label)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundColor(
                                selectedDayOffset == day.id
                                    ? AppTheme.onPrimaryContainer
                                    : .white.opacity(0.7)
                            )
                            .background(
                                selectedDayOffset == day.id
                                    ? AppTheme.primary
                                    : Color.white.opacity(0.10),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, topBarPadding)
        }
    }
    #endif
    
    // MARK: - Now Playing Hero (iOS/macOS)
    
    #if !os(tvOS)
    private var nowPlayingHero: some View {
        let key = currentChannel.streamId.map { "\($0)" } ?? currentChannel.epgChannelId ?? currentChannel.tvgId
        let program = key.flatMap { epgService.nowPlaying(for: $0) }
        
        return Button { onDismiss() } label: {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: currentChannel.logoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primary.opacity(0.25), AppTheme.secondary.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Text(currentChannel.name.prefix(3).uppercased())
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(.white.opacity(0.12))
                        }
                }
                .frame(height: heroHeight)
                .clipped()
                
                LinearGradient(
                    colors: [Color.black.opacity(0.90), Color.black.opacity(0.35), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(program?.title ?? currentChannel.name)
                        .font(AppTypography.heroTitle)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let program {
                        Text(program.description ?? "\(currentChannel.name) \u{2022} \(program.timeRange)")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Button {
                        onDismiss()
                    } label: {
                        Label("Watch Now", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .frame(height: heroHeight)
            .cornerRadius(PlatformMetrics.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: PlatformMetrics.cardCornerRadius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    
    private var heroHeight: CGFloat {
        #if os(macOS)
        return 240
        #else
        return 180
        #endif
    }
    #endif
    
    // MARK: - EPG Grid (shared)
    
    private var epgGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 1) {
                epgTimeHeader
                
                ForEach(orderedChannelList) { channel in
                    epgChannelRow(for: channel)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var epgTimeHeader: some View {
        HStack(spacing: 0) {
            Text("CH.")
                #if os(tvOS)
                .font(.system(size: 16, weight: .bold))
                #else
                .font(AppTypography.label)
                #endif
                .foregroundColor(AppTheme.primary)
                .frame(width: channelLabelWidth, alignment: .leading)
                .padding(.leading, topBarPadding)
            
            ForEach(0..<6, id: \.self) { slotOffset in
                let date = Calendar.current.date(byAdding: .minute, value: slotOffset * 30, to: timelineStart)!
                
                Text(formatTime(date))
                    #if os(tvOS)
                    .font(.system(size: 16, weight: .medium))
                    #else
                    .font(AppTypography.label)
                    #endif
                    .foregroundColor(
                        slotOffset == 0 && selectedDayOffset == 0
                            ? AppTheme.primary
                            : .white.opacity(0.5)
                    )
                    .frame(width: hourWidth / 2, alignment: .leading)
            }
        }
        #if os(tvOS)
        .frame(height: 44)
        #else
        .frame(height: 32)
        #endif
        .background(Color.white.opacity(0.04))
    }
    
    private var channelLogoSize: CGFloat {
        #if os(tvOS)
        return 40
        #else
        return 24
        #endif
    }
    
    private var channelNameFont: Font {
        #if os(tvOS)
        return .system(size: 16, weight: .semibold)
        #else
        return .system(size: 9, weight: .semibold)
        #endif
    }
    
    private var channelNumFont: Font {
        #if os(tvOS)
        return .system(size: 13, weight: .medium)
        #else
        return .system(size: 8, weight: .medium)
        #endif
    }
    
    @ViewBuilder
    private func epgChannelRow(for channel: Channel) -> some View {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId ?? ""
        let programs = epgService.upcoming(for: key)
        let isCurrent = isMatchingChannel(channel, currentChannel)
        
        HStack(spacing: 0) {
            Button {
                onSelectChannel(channel)
            } label: {
                HStack(spacing: 8) {
                    if let logoURL = channel.logoURL {
                        CachedAsyncImage(url: logoURL) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Image(systemName: "tv")
                                .font(.system(size: channelLogoSize * 0.4))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .frame(width: channelLogoSize, height: channelLogoSize)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(channel.name)
                            .font(channelNameFont)
                            .foregroundColor(isCurrent ? AppTheme.primary : .white)
                            .lineLimit(1)
                        
                        if let num = channel.channelNumber {
                            Text("\(num)")
                                .font(channelNumFont)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .frame(width: channelLabelWidth - 8, alignment: .leading)
                .padding(.leading, topBarPadding)
                .padding(.trailing, 4)
            }
            .buttonStyle(.plain)
            
            if programs.isEmpty {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: hourWidth * 3, height: epgRowHeight - 4)
                    .overlay {
                        Text("No data")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.2))
                    }
            } else {
                HStack(spacing: 1) {
                    ForEach(programs.prefix(8)) { program in
                        epgProgramBlock(channel: channel, program: program, isCurrent: isCurrent)
                    }
                }
            }
        }
        .frame(height: epgRowHeight)
        .background(isCurrent ? Color.white.opacity(0.04) : Color.clear)
    }
    
    private var programTitleFont: Font {
        #if os(tvOS)
        return .system(size: 18, weight: .semibold)
        #else
        return .system(size: 10)
        #endif
    }
    
    private var programTimeFont: Font {
        #if os(tvOS)
        return .system(size: 14, weight: .medium)
        #else
        return .system(size: 8, weight: .medium)
        #endif
    }
    
    private func epgProgramBlock(channel: Channel, program: EPGProgram, isCurrent: Bool) -> some View {
        let duration = program.end.timeIntervalSince(program.start) / 3600.0
        let minWidth: CGFloat = {
            #if os(tvOS)
            return 100
            #else
            return 55
            #endif
        }()
        let width = max(minWidth, hourWidth * CGFloat(duration))
        let isNow = program.isNowPlaying
        
        return Button {
            if isNow {
                onSelectChannel(channel)
            } else if channel.hasCatchup, program.end < Date() {
                onPlayCatchup?(channel, program)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    if isNow {
                        #if os(tvOS)
                        LivePulseIndicator(size: 6)
                        #else
                        LivePulseIndicator(size: 4)
                        #endif
                    }
                    Text(program.title)
                        .font(isNow ? programTitleFont.bold() : programTitleFont)
                        .foregroundColor(isNow ? .white : .white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Text(program.timeRange)
                    .font(programTimeFont)
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: width, height: epgRowHeight - 4, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        isNow && isCurrent
                            ? AppTheme.primary.opacity(0.20)
                            : isNow
                                ? AppTheme.primary.opacity(0.10)
                                : Color.white.opacity(0.04)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        isNow ? AppTheme.primary.opacity(0.30) : Color.white.opacity(0.04),
                        lineWidth: isNow ? 1 : 0.5
                    )
            )
            .overlay(alignment: .bottom) {
                if isNow {
                    GlowProgressBar(
                        progress: program.progress,
                        height: 2,
                        trackColor: AppTheme.primary.opacity(0.08),
                        barColor: AppTheme.primary
                    )
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Now Playing Bar (iOS/macOS)
    
    #if !os(tvOS)
    private var nowPlayingBar: some View {
        let key = currentChannel.streamId.map { "\($0)" } ?? currentChannel.epgChannelId ?? currentChannel.tvgId
        let program = key.flatMap { epgService.nowPlaying(for: $0) }
        
        return HStack(spacing: 16) {
            CachedAsyncImage(url: currentChannel.logoURL) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "tv")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
            
            if let num = currentChannel.channelNumber {
                Text("\(num)")
                    .font(AppTypography.label)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW PLAYING")
                    .font(.system(size: 7, weight: .heavy))
                    .tracking(0.6)
                    .foregroundColor(AppTheme.primary)
                
                Text(program?.title ?? currentChannel.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button { onDismiss() } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.primary, in: Circle())
            }
            .buttonStyle(.plain)
            
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, topBarPadding)
        .padding(.vertical, 10)
        .background(
            Color.white.opacity(0.06)
                .background(.ultraThinMaterial)
        )
    }
    #endif
    
    // MARK: - Helpers
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - tvOS EPG Button Styles

#if os(tvOS)
struct EPGChannelButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: isFocused ? AppTheme.primary.opacity(0.3) : .clear, radius: 8)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

struct EPGProgramButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? AppTheme.primary.opacity(0.5) : .clear, lineWidth: 1.5)
            )
            .shadow(color: isFocused ? AppTheme.primary.opacity(0.25) : .clear, radius: 6)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
#endif
