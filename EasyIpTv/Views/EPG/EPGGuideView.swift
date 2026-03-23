import SwiftUI

/// Electronic Program Guide -- Liquid Glass redesign
struct EPGGuideView: View {
    let channels: [Channel]
    @ObservedObject var epgService = EPGService.shared
    @State private var selectedChannel: Channel?
    @State private var timeOffset: CGFloat = 0
    var onPlayChannel: ((Channel) -> Void)?
    var onPlayCatchup: ((Channel, EPGProgram) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    
    private let hourWidth: CGFloat = 200
    private let channelLabelWidth: CGFloat = 180
    
    private var channelRowHeight: CGFloat {
        #if os(tvOS)
        return 80
        #else
        return 64
        #endif
    }
    
    private var now: Date { Date() }
    
    private var timelineStart: Date {
        Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: now) - 1, minute: 0, second: 0, of: now) ?? now
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(scheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if channels.isEmpty {
                        ContentUnavailableView(
                            "No EPG Data",
                            systemImage: "tv.badge.ellipsis",
                            description: Text("EPG data is not available for your current playlist.")
                        )
                    } else {
                        epgGrid
                    }
                }
            }
            .navigationTitle("TV Guide")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }
    
    @ViewBuilder
    private var epgGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 1) {
                timeHeader
                    .padding(.leading, channelLabelWidth)
                
                ForEach(channels.prefix(50)) { channel in
                    channelRow(for: channel)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private var timeHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hourOffset in
                let date = Calendar.current.date(byAdding: .hour, value: hourOffset, to: timelineStart)!
                
                VStack(spacing: 2) {
                    Text(formatHour(date))
                        .font(AppTypography.label)
                        .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                    
                    Rectangle()
                        .fill(AppTheme.outlineVariant(scheme))
                        .frame(width: 1, height: 8)
                }
                .frame(width: hourWidth, alignment: .leading)
                .padding(.leading, 4)
            }
        }
        .frame(height: 32)
        .background(AppTheme.surfaceContainerLow(scheme).opacity(0.80))
    }
    
    @ViewBuilder
    private func channelRow(for channel: Channel) -> some View {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId ?? ""
        let programs = epgService.upcoming(for: key)
        
        HStack(spacing: 0) {
            channelLabel(for: channel)
            
            if programs.isEmpty {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.surfaceContainerHigh(scheme))
                    .frame(width: hourWidth * 3, height: channelRowHeight - 6)
                    .overlay {
                        Text("No data")
                            .font(AppTypography.caption)
                            .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                    }
            } else {
                HStack(spacing: 1) {
                    ForEach(programs.prefix(12)) { program in
                        programBlock(channel: channel, program: program)
                    }
                }
            }
        }
        .frame(height: channelRowHeight)
    }
    
    private func channelLabel(for channel: Channel) -> some View {
        HStack(spacing: 10) {
            if let logoURL = channel.logoURL {
                CachedAsyncImage(url: logoURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "tv")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                }
                .frame(width: 32, height: 32)
                .background(AppTheme.surfaceContainerHigh(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.onSurface(scheme))
                    .lineLimit(1)
                
                if let num = channel.channelNumber {
                    Text("Ch \(num)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.onSurfaceVariant(scheme))
                }
            }
        }
        .frame(width: channelLabelWidth - 12, alignment: .leading)
        .padding(.horizontal, 6)
        .background(AppTheme.surfaceContainerLow(scheme).opacity(0.60))
    }
    
    private func programBlock(channel: Channel, program: EPGProgram) -> some View {
        let duration = program.end.timeIntervalSince(program.start) / 3600.0
        let width = max(60, hourWidth * CGFloat(duration))
        let isNow = program.isNowPlaying
        
        return Button {
            if isNow {
                onPlayChannel?(channel)
            } else if channel.hasCatchup, program.end < Date() {
                onPlayCatchup?(channel, program)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if isNow {
                        LivePulseIndicator(size: 4)
                    }
                    Text(program.title)
                        .font(AppTypography.caption)
                        .fontWeight(isNow ? .bold : .medium)
                        .foregroundColor(
                            isNow ? AppTheme.onSurface(scheme) : AppTheme.onSurfaceVariant(scheme)
                        )
                        .lineLimit(1)
                }
                
                Text(program.timeRange)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.onSurfaceVariant(scheme).opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: width, height: channelRowHeight - 6, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isNow
                            ? AppTheme.primary.opacity(0.15)
                            : AppTheme.surfaceContainer(scheme)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isNow ? AppTheme.primary.opacity(0.30) : AppTheme.glassBorder(scheme),
                        lineWidth: isNow ? 1 : 0.5
                    )
            )
            .overlay(alignment: .bottom) {
                if isNow {
                    GlowProgressBar(
                        progress: program.progress,
                        height: 2,
                        trackColor: AppTheme.primary.opacity(0.10),
                        barColor: AppTheme.primary
                    )
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatHour(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
