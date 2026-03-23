import SwiftUI

/// Full-screen EPG guide overlay shown while watching live TV.
/// Displays day selector, featured "now playing" hero, and an EPG grid
/// with channels and their program schedules.
struct PlayerEPGOverlay: View {
    let channels: [Channel]
    let currentChannel: Channel
    var onSelectChannel: (Channel) -> Void = { _ in }
    var onPlayCatchup: ((Channel, EPGProgram) -> Void)? = nil
    var onDismiss: () -> Void = {}
    
    @ObservedObject private var epgService = EPGService.shared
    @State private var selectedDayOffset = 0
    
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
    }
    
    // MARK: - Top Bar
    
    private var topBarPadding: CGFloat {
        #if os(tvOS)
        return 60
        #else
        return 20
        #endif
    }
    
    private var topBar: some View {
        HStack {
            Text("Live")
                .font(AppTypography.sectionTitle)
                .foregroundColor(.white)
            
            Spacer()
            
            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    #if os(tvOS)
                    .font(.system(size: 36))
                    #else
                    .font(.system(size: 24))
                    #endif
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, topBarPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Day Pills
    
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
                            #if os(tvOS)
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            #else
                            .font(AppTypography.label)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            #endif
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
    
    // MARK: - Now Playing Hero
    
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
        #if os(tvOS)
        return 300
        #elseif os(macOS)
        return 240
        #else
        return 180
        #endif
    }
    
    // MARK: - EPG Grid
    
    private var epgGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 1) {
                epgTimeHeader
                
                ForEach(channels.prefix(30)) { channel in
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
        let isCurrent = channel.id == currentChannel.id
        
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
    
    // MARK: - Now Playing Bar
    
    private var nowPlayingBar: some View {
        let key = currentChannel.streamId.map { "\($0)" } ?? currentChannel.epgChannelId ?? currentChannel.tvgId
        let program = key.flatMap { epgService.nowPlaying(for: $0) }
        
        return HStack(spacing: 16) {
            CachedAsyncImage(url: currentChannel.logoURL) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "tv")
                    #if os(tvOS)
                    .font(.system(size: 18))
                    #else
                    .font(.system(size: 10))
                    #endif
                    .foregroundColor(.white.opacity(0.3))
            }
            #if os(tvOS)
            .frame(width: 48, height: 48)
            #else
            .frame(width: 28, height: 28)
            #endif
            .background(Color.white.opacity(0.08))
            .clipShape(Circle())
            
            if let num = currentChannel.channelNumber {
                Text("\(num)")
                    .font(AppTypography.label)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW PLAYING")
                    #if os(tvOS)
                    .font(.system(size: 12, weight: .heavy))
                    #else
                    .font(.system(size: 7, weight: .heavy))
                    #endif
                    .tracking(0.6)
                    .foregroundColor(AppTheme.primary)
                
                Text(program?.title ?? currentChannel.name)
                    #if os(tvOS)
                    .font(AppTypography.body)
                    #else
                    .font(AppTypography.bodyMedium)
                    #endif
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button { onDismiss() } label: {
                Image(systemName: "pause.fill")
                    #if os(tvOS)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    #else
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    #endif
                    .background(AppTheme.primary, in: Circle())
            }
            .buttonStyle(.plain)
            
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    #if os(tvOS)
                    .font(.system(size: 18, weight: .bold))
                    #else
                    .font(.system(size: 11, weight: .bold))
                    #endif
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, topBarPadding)
        #if os(tvOS)
        .padding(.vertical, 16)
        #else
        .padding(.vertical, 10)
        #endif
        .background(
            Color.white.opacity(0.06)
                .background(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
